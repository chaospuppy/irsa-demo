#!/usr/bin/env python3

import sys
import logging
import os
import boto3
import argparse
import io
import json
import base64
import hashlib
from jwcrypto import jwk


from botocore.exceptions import ClientError
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

try:
    session = boto3.session.Session(profile_name=os.environ["AWS_PROFILE"])
except KeyError:
    print("AWS_PROFILE not set, exiting")
    sys.exit(1)

REGION = session.region_name
ISSUER_HOSTNAME = f"s3-{REGION}.amazonaws.com"
# TODO This may actually change one day...
THUMBPRINT = "CD3E919FBBEA084F9140937ED3555066E20CBB28"


def upload_oidc_documents(bucket_name: str, kid: str, public_key: rsa.RSAPublicKey, dryrun: bool) -> None:
    s3 = session.client("s3")

    jwk_key = jwk.JWK.from_pem(public_key)
    jwk_key.setdefault("use", "sig")
    jwk_key.setdefault("alg", "RS256")
    jwk_key.update(kid=kid)
    jwks = jwk.JWKSet(keys=jwk_key)

    if not dryrun:
        try:
            response = s3.upload_fileobj(
                io.BytesIO(jwks.export().encode("utf-8")),
                bucket_name,
                "keys.json",
                ExtraArgs={"ACL": "public-read", "ContentType": "application/json"},
            )
        except ClientError as e:
            logging.exception(e)
            sys.exit(1)
    else:
        print(jwks.export())

    discovery = {
        "issuer": f"https://{ISSUER_HOSTNAME}/{bucket_name}",
        "jwks_uri": f"https://{ISSUER_HOSTNAME}/{bucket_name}/keys.json",
        "authorization_endpoint": "urn:kubernetes:programmatic_authorization",
        "response_types_supported": ["id_token"],
        "subject_types_supported": ["public"],
        "id_token_signing_alg_values_supported": ["RS256"],
        "claims_supported": ["sub", "iss"],
    }
    if not dryrun:
        try:
            response = s3.upload_fileobj(
                io.BytesIO(json.dumps(discovery).encode("utf-8")),
                bucket_name,
                ".well-known/openid-configuration",
                ExtraArgs={"ACL": "public-read"},
            )
        except ClientError as e:
            logging.error(e)
            sys.exit(1)
    else:
        print(json.dumps(discovery))


# Generate Service Account public and private signing key files
def generate_signing_keys() -> (str, rsa.RSAPrivateKey):
    key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )

    private_key = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    with open("sa-signer.key", "w") as f:
        f.write(private_key.decode("utf-8"))

    public_key = key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    with open("sa-signer-pkcs8.pub", "w") as f:
        f.write(public_key.decode("utf-8"))

    public_key_der = key.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )

    hasher = hashlib.sha256(public_key_der).digest()
    kid = base64.urlsafe_b64encode(hasher).decode().rstrip("=")

    return kid, public_key


def generate_idm_json(aud: str, bucket: str) -> None:
    idm_json = {
        "Url": f"https://{ISSUER_HOSTNAME}/{bucket}",
        "ClientIDList": aud,
        "ThumbprintList": [f"{THUMBPRINT}"],
    }

    print(json.dumps(idm_json))


def main():
    parser = argparse.ArgumentParser(
        description="Provides useful automation for configuring and external OIDC provider for kubernetes"
    )
    parser.add_argument(
        "--bucket-name",
        type=str,
        help="name of bucket to host OIDC documents",
    )
    parser.add_argument(
        "--audiences",
        type=list[str],
        default=["sts.amazonaws.com"],
        help="Audience to be used in Identity Provider configuration",
    )
    parser.add_argument(
        "--generate-idm-json",
        action="store_true",
        default=False,
        help="optionally output JSON that can be used to create an Identity Provider in AWS",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Don't upload new oidc and jwks, just print them",
    )

    args = parser.parse_args()

    kid, public_key = generate_signing_keys()
    upload_oidc_documents(args.bucket_name, kid, public_key, args.dry_run)

    if args.generate_idm_json:
        generate_idm_json(args.audiences, args.bucket_name)


if __name__ == "__main__":
    sys.exit(main())
