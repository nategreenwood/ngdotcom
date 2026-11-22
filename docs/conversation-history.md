# Conversation history — planning session (2026-10-31)

Record of the planning session that started this project, so a new Claude session can pick up with full context.

---

## 1. User request

> I have a hosted website that I'm not renewing. I still have the domain and it's pointing to the site. Site and domain is hosted through discountasp.net, nate.greenwood.com. I would like to create a personal/professional website on .net stack and angular frontend and preferably host on Azure — the setup as simple as can be made. Finally I want my current domain to point to the Azure hosted site.
>
> Create a plan on how to accomplish this.

## 2. Plan (Claude's answer)

### Recommended architecture: Azure Static Web Apps (Free tier)

- **Frontend:** Angular, served from Azure's global CDN.
- **Backend:** C# API on **.NET 10** (Azure Functions, isolated worker). SWA hosts it, so there's no separate server to manage. Microsoft's docs confirm SWA supports `dotnet-isolated:10.0`.
- **Cost:** $0 on the Free tier, including free auto-renewing HTTPS certificates and up to 2 custom domains.
- **Deployment:** pushing to GitHub builds and deploys automatically.
- **No CORS setup:** the site and API share one domain, with `/api/*` going to the .NET functions.

**Why not Azure App Service?** Its free F1 tier doesn't allow custom domains. B1 costs about $13/month and means managing a server. It's only worth it later for a full ASP.NET Core app with long-running work, and linking it to SWA requires the Standard plan.

### Phase 0: Before cancelling the old hosting
1. Back up the current site: FTP down the files, export any database, save images and content worth reusing.
2. Separate the domain from the hosting. *(Resolved; see section 4. The registration and DNS stay at DiscountASP.NET for another year.)*
3. Write down the existing DNS records, especially MX/email records if email runs on the domain.
4. Confirm whether the domain is the subdomain `nate.greenwood.com` (CNAME, simple) or a root domain (needs ALIAS, see Phase 4).

### Phase 1: Tools (one-time)
- .NET 10 SDK, Node.js 22 LTS, Angular CLI (`npm i -g @angular/cli`)
- Azure Functions Core Tools v4, SWA CLI (`npm i -g @azure/static-web-apps-cli`)
- VS Code with the Azure Static Web Apps and Azure Functions extensions, or Visual Studio
- GitHub account and Azure account (free is enough)

### Phase 2: Build the site
Repo structure:
```
/client   → Angular app (standalone components, routing)
/api      → .NET 10 isolated Azure Functions (C#)
staticwebapp.config.json
```
- **Pages:** Home/About, Experience/Resume, Projects/Portfolio, Contact, optional Blog.
- **API (start small):** `GET /api/projects`, `POST /api/contact`. The contact form sends email through a free SendGrid or Azure Communication Services tier.
- **Content:** JSON files in the repo to start. Add Cosmos DB free tier or Azure Table Storage only if needed.
- **Config:** `"navigationFallback": { "rewrite": "/index.html" }` and `"platform": { "apiRuntime": "dotnet-isolated:10.0" }`.
- **Local dev:** `swa start` runs Angular and the API together, as they'll run in Azure.

### Phase 3: Deploy to Azure
1. Azure Portal: create a Static Web App on the **Free** plan, connected to the GitHub repo.
2. Build preset **Angular**: app location `client`, API location `api`, output location `dist/<app>/browser`.
3. Azure adds a GitHub Actions workflow. Pushes to `main` deploy, and pull requests get preview URLs.
4. Check the site at the generated `*.azurestaticapps.net` address.

### Phase 4: Point the domain to Azure
**Subdomain `nate.greenwood.com`:**
1. Portal: **Custom domains**, choose **Add**, enter `nate.greenwood.com`.
2. In DNS (DiscountASP.NET control panel), replace the `nate` record with a **CNAME** pointing to `<your-app>.azurestaticapps.net`.
3. Azure validates the domain and issues the HTTPS certificate automatically, usually within minutes, up to a few hours.

**Root domain:** add it with TXT validation, then use an ALIAS/ANAME record. If the DNS host doesn't support ALIAS, move DNS to Azure DNS (about $0.50/month) or Cloudflare (free), and add a `www` CNAME with a redirect.

**To avoid downtime:** lower the record's TTL to 5 minutes a day before switching, change the record, confirm the new site loads over HTTPS, and only then cancel the hosting.

### Phase 5: Afterwards
- Application Insights (free) for API error monitoring.
- Azure budget alert at $1–5.
- SEO basics: page titles and meta tags, `sitemap.xml`, Open Graph tags for LinkedIn previews.

**Order to follow:** back up → build and run locally → deploy to the Azure address → switch DNS → confirm HTTPS → cancel the old hosting.

**Expected cost:** $0/month (plus about $0.50/month only if Azure DNS is needed), plus domain renewal.

## 3. Follow-up

Claude offered to scaffold the Angular + .NET project. **User: "Not yet."**

## 4. Clarification from user

> I'm only cancelling hosting, I have the domain registration and all the tools through discountasp.net for another year.

So the domain registration and DNS management stay at DiscountASP.NET until about October 2027. No transfer is needed now. DNS changes in Phase 4 are made in the DiscountASP.NET control panel. Before that registration term ends, decide whether to renew there or transfer the domain to another registrar.

The user then asked to create this `personal-site` folder, `git init` it, and save this history here for a new Claude session.
