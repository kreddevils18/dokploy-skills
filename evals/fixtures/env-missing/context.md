App `api` in Dokploy environment `staging`. Its env contains references such as
STORAGE_ENDPOINT=${{environment.STORAGE_ENDPOINT}} and STORAGE_BUCKET=${{environment.STORAGE_BUCKET}}.
Ten minutes ago the user edited the staging Environment Variables to fix STORAGE_ENDPOINT, then clicked Deploy.
Deployment record: status "error", started 09:25:44.338Z, finished 09:25:44.652Z.
