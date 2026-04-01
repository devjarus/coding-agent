# Ideation Council Perspective Prompts

## Step 1: Assess Needed Perspectives

| Perspective | Dispatch when... | Skip when... |
|-------------|------------------|--------------|
| **Product** | New features, user-facing changes, prioritization, MVP scoping | Pure refactoring, infra-only changes |
| **Architecture** | New systems, tech stack decisions, scalability, integration patterns | Simple feature additions to established codebase |
| **Deployment** | New services, hosting decisions, environment setup, going to production | Changes to existing deployed features |
| **Security** | Auth, user data, payments, external APIs, LLM integration | Internal tools with no sensitive data |
| **Data** | New data models, database choices, migration from existing schemas | Frontend-only changes |
| **Cost** | Cloud infrastructure, LLM API usage, scaling decisions, vendor choices | Small features with negligible cost impact |

**Most queries need 2-3 perspectives, not all 6.**

## Step 2: Perspective Research Prompts

### Product Perspective
```
Research from a PRODUCT perspective:
- Who are the target users? What problems does this solve?
- What do comparable products do well? What do they get wrong?
- Must-have features for MVP vs nice-to-haves for later?
- User journey: discover, start using, get value?
- Monetization or growth considerations?
Return: structured findings with specific recommendations.
```

### Architecture Perspective
```
Research from an ARCHITECTURE perspective:
- Right system architecture? (monolith, microservices, serverless, hybrid)
- Best tech stack given requirements and team context?
- Key integration points and data flows?
- Scalability bottlenecks and design solutions?
- Proven patterns for this type of system? (reference real open-source projects)
Return: architecture diagram description and tech stack recommendation.
```

### Deployment Perspective
```
Research from a DEPLOYMENT perspective:
- Right hosting strategy? (serverless, containers, PaaS, edge)
- What environments are needed? (dev, staging, prod)
- CI/CD pipeline structure?
- Operational requirements? (monitoring, alerting, logging, backups)
- Estimated infrastructure cost at launch and at 10x scale?
Return: hosting recommendation and cost estimate.
```

### Security Perspective
```
Research from a SECURITY perspective:
- Threat vectors for this type of application?
- Appropriate auth/authz model?
- What data needs protection and at what level?
- Compliance requirements? (GDPR, SOC2, HIPAA)
- If LLM-powered: prompt injection and data leakage risks?
Return: security requirements and threat model.
```

### Data Perspective
```
Research from a DATA perspective:
- What data models are needed? Key entities and relationships?
- What database type fits? (relational, document, graph, time-series, vector)
- Expected data volume and access patterns?
- Migration concerns from existing schemas?
- Appropriate caching strategy?
Return: data model sketch and database recommendation.
```

### Cost Perspective
```
Research from a COST perspective:
- Main cost drivers? (compute, storage, API calls, bandwidth)
- Estimated monthly cost at launch? At 10x users?
- Cost optimization opportunities? (reserved instances, caching, CDN)
- Expensive dependencies? (LLM APIs, third-party services)
- Cost of recommended tech stack vs alternatives?
Return: cost breakdown table.
```

## Step 3: Synthesize and Present

```
**Council Findings:**

**Product:** [1-2 sentence summary]
**Architecture:** [1-2 sentence summary + recommended stack]
**Deployment:** [1-2 sentence summary + recommended hosting]
[other perspectives if dispatched]

**Recommendation:** [unified recommendation balancing all perspectives]
**Tradeoffs:** [key tensions between perspectives]
**Open questions:** [anything unresolved for user input]
```
