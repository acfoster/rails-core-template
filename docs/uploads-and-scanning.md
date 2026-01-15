# Uploads & Scanning

This doc covers file upload flow and malware scanning.

## Upload Flow (High Level)
- User uploads a file from an authenticated page.
- The file is stored temporarily (not persisted in DB).
- We scan the file before any background processing.
- Temporary files are cleaned after processing.

## Virus Scanning Providers
We currently support:
- **Cloudmersive API** (primary)
- **ClamAV** (optional local scanning)

### Cloudmersive
Required ENV:
- `CLOUDMERSIVE_API_KEY`
- `ENABLE_VIRUS_SCAN=true`

Notes:
- Cloudmersive free tier has monthly limits.
- On failure, the upload is rejected and the temp file is cleaned up.

### ClamAV (Optional)
If you run ClamAV locally (e.g., Docker), ensure:
- The daemon is running and accessible from the app container.
- You have updated the virus definitions regularly.

## Troubleshooting
- If scans fail, check network access and API keys.
- For ClamAV, ensure the socket/port is reachable.
