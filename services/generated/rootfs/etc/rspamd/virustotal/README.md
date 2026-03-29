# VirusTotal Integration for Rspamd  
External Python microservice and Lua symbol

## 1. Scope and constraints

This directory contains the files needed to integrate Rspamd with VirusTotal using:

- A local Python microservice that talks to the VirusTotal HTTP API
- A custom Lua symbol in Rspamd that calls the microservice

This integration is designed for the **VirusTotal public API**.

According to VirusTotal documentation, the public API:

- Is limited to **4 requests per minute**
- Is limited to **500 requests per day**
- Is intended for non commercial, low volume usage
- Must not be used in commercial products or business workflows that do not contribute new files

Use a premium VirusTotal API key if you intend to rely on this in a commercial or higher volume context.

## 2. Components

This directory defines the following components:

- `vt_service.py`  
  Python HTTP microservice that:
  - Listens on `127.0.0.1:9470`
  - Receives JSON requests with file hashes
  - Enforces public API rate limits
  - Caches results in memory
  - Calls VirusTotal v3 API and returns a simple JSON verdict

- `vt.env.example`  
  Example environment file showing the expected variables. The real secrets will be stored on the OpenBSD host at `/root/.config/virustotal/vt.env` and must **not** be committed to git.

- `requirements.txt`  
  Python dependencies for the microservice.

- `virustotal.lua`  
  Rspamd Lua rule that:
  - Registers symbol `VIRUSTOTAL_CHECK` as a `postfilter` symbol
  - Computes SHA-256 hashes for MIME attachments only
  - Skips messages that have no attachments
  - Calls `vt_service.py` over HTTP
  - Inserts one of `VT_CLEAN`, `VT_SUSPICIOUS`, `VT_MALICIOUS` symbols based on the result

- `rc_virustotal_service`  
  OpenBSD rc.d template for managing `vt_service.py` as a daemon.

## 3. Installation overview

High level deployment steps on the OpenBSD mail host:

1. Create `/root/.config/virustotal/vt.env` from `vt.env.example` and insert a real VirusTotal API key.
2. Install Python requirements from `requirements.txt`.
3. Copy `vt_service.py` to `/usr/local/sbin/vt_service.py` and configure an rc.d script derived from `rc_virustotal_service`.
4. Install `virustotal.lua` into `/etc/rspamd/lua.local.d/`.
5. Extend Rspamd scoring config to define `VIRUSTOTAL_CHECK`, `VT_CLEAN`, `VT_SUSPICIOUS`, `VT_MALICIOUS`.
6. Reload Rspamd and verify that:
   - `vt_service.py` is listening on `127.0.0.1:9470`
   - Rspamd can call the microservice
   - VirusTotal symbols appear in scans when appropriate

## 4. Files under configuration management

The following files are tracked in git and should be modified here in the repo:

- `vt_service.py`
- `requirements.txt`
- `vt.env.example`
- `virustotal.lua`
- `rc_virustotal_service`
- `README.md`

The following file is **not** tracked in git and will only exist on the mail host:

- `/root/.config/virustotal/vt.env`
