# Vault and Consul Enterprise Google Image

## Encrypting your Vault Enterprise license

We recommend encrypting your license key locally using the Google KMS tools.

You can simply extend the Packer template to decrypt your license key when baking the image or during startup in the `start-script-vault.sh` script.

```bash
$ gcloud kms decrypt --keyring=gruntwork-test --key=vault-test --location=global --ciphertext-file=/opt/vault/vault-license.hclic.enc --plaintext-file=/opt/vault/vault-license.hclic
```
