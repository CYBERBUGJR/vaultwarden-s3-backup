# vaultwarden-s3-backup
Backup Vaultwarden (with SQLITE) to S3. Also backups rsa-keys, attachments, sends, etc.
Adapted for l0rd.be env.



## Environment variables

- `DATA_DIR` Directory where all vaultwarden-data is stored (default: '/data')
- `AGE_KEY_FILE` your age key file for encryption *required* 
- `S3_ACCESS_KEY_ID` your AWS access key *required*
- `S3_SECRET_ACCESS_KEY` your AWS secret key *required*
- `S3_BUCKET` your AWS S3 bucket path *required*
- `AWS_REGION` your AWS region (default: eu-west-1)
- `S3_PREFIX` path prefix in your bucket (default: 'backup')
- `S3_S3V4` set to `yes` to enable AWS Signature Version 4, required for [minio](https://minio.io) servers (default: no)
  `RETENTION` Defines a bucket-policy in S3

## Restoring
Restoring is possbible ,too ;-) Restoring is an interactive job, so it has to be done like this

```sh
$ docker run -e S3_ACCESS_KEY_ID=key -e S3_SECRET_ACCESS_KEY=secret -e S3_BUCKET=my-bucket -e S3_PREFIX=backup -e S3_ENDPOINT=https://s3.*** -ti -v /vaultwarden-data:/data  vaultwarden-s3-backup /bin/bash
bash-5.1$ ./restore.sh
Select a backup to restore
1) backup.2022-09-30T08_58_03Z.tar.gz  3) backup.2022-09-29T13_22_37Z.tar.gz  5) backup.2022-09-29T13_15_26Z.tar.gz
2) backup.2022-09-29T13_27_50Z.tar.gz  4) backup.2022-09-29T13_16_39Z.tar.gz  6) backup.2022-09-29T13_10_01Z.tar.gz
#?
```

After selecting the file, the restore-process starts immediately. **All existing files will be overwritten !!!**

## Running in Kubernetes
Since the sqlite database resides in the persistent-volume of the vaultwarden-pod it is crucial that the backup-pod needs access to this volume, too.
This can be achieved by running the backup-pod on the same host as the vaultwarden-pod (using pod-affinity-rules)

Create secret for S3-Credentials

```bash
mkdir secrets
pushd secrets
echo -n 'ACCESS' > S3_ACCESS_KEY_ID
echo -n 'SECRET' > S3_SECRET_ACCESS_KEY
echo -n 'BUCKET' > S3_BUCKET
echo -n 'REGION' > AWS_REGION
kubectl -n bitwarden create secret generic s3-backup \
    --from-file=./S3_ACCESS_KEY_ID \
    --from-file=./S3_SECRET_ACCESS_KEY \
    --from-file=./S3_BUCKET \
    --from-file=./AWS_REGION
popd
podman run --rm alpine /bin/sh -c "apk add -qq age ; age-keygen" > age-keys
kubectl -n bitwarden create secret generic bitwarden-age-keys --from-file=.age.key=./age-keys
rm -f ./age-keys
rm -rf ./secrets
```

Create Kubernetes Cronjob (here is one that runs every 4 hours)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: bitwarden-backup
spec:
  schedule: "0 0 * * *"
  successfulJobsHistoryLimit: 1
  concurrencyPolicy: Replace
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          affinity:
            podAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
              - labelSelector:
                  matchExpressions:
                  - key: app.kubernetes.io/name
                    operator: In
                    values: 
                    -  bitwarden-k8s
                topologyKey: kubernetes.io/hostname
          containers:
          - name: backup
            image: ghcr.io/cyberbugjr/vaultwarden-s3-backup:latest@sha256:----
            envFrom:
            - secretRef:
                name: s3-backup
            env:
            - name: S3_PREFIX
              value: bitwarden
            - name: AGE_KEY_FILE
              value: /app/.age.key
            volumeMounts:
            - mountPath: "/data"
              name: data
              readOnly: true
            - mountPath: "/app/.age.key"
              name: age
              readOnly: true
          restartPolicy: Never
          volumes:
          - name: data
            hostPath:
              path: /mnt/DEADPOOL/data/Bitwarden
              type: Directory
          - name: age
            secret:
              secretName: bitwarden-age-keys