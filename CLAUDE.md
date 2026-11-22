# personal-site

Personal/professional website for nategreenwood.com (an apex/root domain, not a subdomain), replacing a site hosted at DiscountASP.NET.

## Context
- Full planning history: [docs/conversation-history.md](docs/conversation-history.md). Read it before starting work.
- Status: scaffolding. `/client` exists (Angular 21, project name `ngdotcom`, SCSS, no SSR, Vitest). `/api` exists (.NET 10 isolated Functions, ASP.NET Core integration, one HTTP function `projects`).
- Working style: the user does the work as a learning project; Claude guides, explains, and reviews.
- Local toolchain: Node 24 LTS, .NET 10 SDK, Angular CLI 21, Functions Core Tools 4.15, SWA CLI 2.1.

## Decisions
- **Stack:** Angular frontend (`/client`) + .NET 10 isolated Azure Functions API (`/api`).
- **Hosting:** Azure Static Web Apps, Free tier, deployed through GitHub Actions.
- **Config:** `client/staticwebapp.config.json` (it must be in `app_location`, which is `client`), with `navigationFallback` → `/index.html` and `apiRuntime: dotnet-isolated:10.0`.
- **Build output:** `client/dist/ngdotcom/browser` (SWA "output location" is `dist/ngdotcom/browser`).
- **Content:** JSON files in the repo to start. No database unless needed.
- **Goal:** keep the setup as simple as possible.

## Domain / DNS
- Only the DiscountASP.NET *hosting* is being cancelled. Domain registration and DNS stay at DiscountASP.NET until about October 2027.
- `nategreenwood.com` is an apex domain, so a plain CNAME at the root isn't allowed. SWA validates an apex domain with a TXT record, then the root needs an ALIAS/ANAME (or CNAME-flattening) record pointing to `<app>.azurestaticapps.net`.
- Open question: does DiscountASP.NET DNS support ALIAS/ANAME? If not, move only the DNS (nameservers) to Azure DNS (~$0.50/mo) or Cloudflare (free). The registration stays at DiscountASP.NET either way.
- Also add `www.nategreenwood.com` as a CNAME and redirect it to the apex domain. The SWA Free tier allows 2 custom domains, so both fit.
- Cut-over: lower the TTL first, switch the records, confirm HTTPS works, then cancel the hosting.
- Keep any existing MX/email records intact.
