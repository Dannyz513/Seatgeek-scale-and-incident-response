# Design Document: Scalable Ticketing Platform Infrastructure

**Framing:** How I would architect infrastructure for a company like SeatGeek — a ticket marketplace where traffic is calm most of the time, then spikes by 50-100x in the first few minutes of a major on-sale.

This is a design exercise based on SeatGeek's publicly known business model (ticket on-sales causing extreme, predictable traffic spikes), not a claim about their actual internal infrastructure, which I have no visibility into.

## 1. Problem Statement

At ~1,000 employees, this company runs a ticket marketplace with two very different traffic regimes:
- **Steady state:** normal day-to-day browsing and purchases
- **On-sale spikes:** a handful of times a year, a high-demand event goes on sale at a known time, and traffic increases by 50-100x within minutes, then falls off over the following hour

The infrastructure needs to:
1. Handle both regimes without over-provisioning for peak 365 days a year
2. Detect when something is actually going wrong (not just "traffic is high") — latency degradation, error rates, capacity exhaustion
3. Turn every alarm into a permanent, structured record for postmortem analysis — not just a Slack ping that gets missed at 2am during a launch

## 2. Requirements

| Requirement | Why it matters |
|---|---|
| Scale ahead of known on-sale times | Reactive-only scaling is too slow for a spike that arrives in seconds, not minutes |
| Scale automatically for unplanned spikes too | Not every spike is scheduled (e.g., a surprise announcement) |
| Alert humans immediately when thresholds are breached | Someone needs to know *now*, not after the postmortem |
| Persist every incident for later analysis | Alerts get missed; a database record doesn't |
| Stay cost-reasonable in steady state | Most of the year, this system should not be running peak-sized infrastructure |

## 3. Architecture

- **VPC** across 2 Availability Zones — public subnets for the load balancer, private subnets for application instances
- **Application Load Balancer** distributing traffic to an **Auto Scaling Group**
- **Two scaling mechanisms working together:**
  - **Scheduled scaling**, pre-warming capacity ahead of a known on-sale time (set manually or via an internal tool, out of scope here) — because reactive scaling alone is too slow for a spike that arrives in under a minute
  - **Target-tracking scaling on ALB request count per target**, not CPU — request count reacts faster to a traffic surge than CPU utilization does, which lags behind actual load
- **CloudWatch Alarms** on the signals that actually indicate a problem, not just "traffic is high":
  - p99 target response time breaching an SLO threshold for 3 consecutive periods (avoids alarming on a single noisy data point)
  - ALB 5xx error rate exceeding a threshold (real user-facing failures)
  - Auto Scaling Group at maximum capacity (a leading indicator that capacity planning was wrong, not just a lagging one)
- **SNS** for immediate human notification
- **EventBridge Rule** capturing CloudWatch alarm state changes, routing to **Lambda**
- **Lambda** writes a structured incident record to **DynamoDB**: timestamp, alarm name, metric, threshold, breaching value, alarm state — a permanent, queryable history instead of a transient notification

## 4. Key Design Decisions

**Why request-count-per-target instead of CPU-based scaling?**
CPU utilization is a lagging indicator — by the time CPU spikes, requests may already be queuing or timing out. Request count per target reacts to load directly and scales faster during a sudden burst.

**Why scheduled scaling in addition to reactive scaling?**
For a known on-sale time, waiting for reactive metrics to breach a threshold before scaling wastes precious seconds during the exact window when it matters most. Pre-warming capacity ahead of a known event is a real technique used by high-traffic ticketing and e-commerce platforms.

**Why EventBridge → Lambda → DynamoDB instead of just SNS?**
SNS alone notifies a human in the moment, but that notification is transient — if it's missed, the information is effectively gone. Writing every alarm to DynamoDB creates a permanent, queryable incident log that supports postmortems, trend analysis ("how often does this alarm fire?"), and on-call handoffs, without relying on someone's inbox or Slack scrollback.

**Why alarm on 3 consecutive breaching periods instead of 1?**
A single noisy data point shouldn't page anyone. Requiring sustained breach reduces false-positive alerts while still catching real, ongoing problems quickly.

## 5. AWS Well-Architected Framework Alignment

| Pillar | How this design addresses it |
|---|---|
| **Reliability** | Multi-AZ deployment, Auto Scaling Group maintains desired capacity, health-check-based instance replacement |
| **Performance Efficiency** | Request-count-based scaling responds to actual load characteristics rather than a proxy metric (CPU) |
| **Operational Excellence** | Every alarm becomes a structured, permanent incident record — supporting retrospectives and trend analysis rather than relying on tribal memory |
| **Cost Optimization** | Steady-state capacity stays small; scaling (scheduled and reactive) only provisions peak capacity when actually needed |
| **Security** | Least-privilege IAM throughout — the incident-logging Lambda can only write to its one DynamoDB table, nothing broader |

## 6. Deliberately Out of Scope

A senior design doc states what's excluded and why, rather than pretending the design is complete:

- **Multi-region failover** — adds significant cost and operational complexity; appropriate once a single region's blast radius becomes unacceptable, not by default
- **WAF / Shield Advanced** — real production systems facing this kind of demand would want this for bot/scalper mitigation during on-sales, but it's a distinct problem space from the scaling/alerting story this project demonstrates
- **RDS read replicas / caching layer (ElastiCache)** — the compute and alerting layer is the focus here; a real system at this scale would almost certainly need a caching layer in front of the database, which is a natural next iteration
- **A dashboard/UI for the incident log** — the DynamoDB table is queryable via CLI/console for this project; a real team would likely put a lightweight internal tool or QuickSight dashboard on top

## 6a. Why a Single Region (Not One Region Per Event Location)

A natural question: if ticket sales are for events in specific cities, why not deploy infrastructure closer to each event?

Because **where an event happens and where buyers are located are different things** — a concert in Los Angeles is bought by people across the country, not just Angelenos. Region selection should be driven by where *users* are and what *consistency guarantees* the system needs, not by matching infrastructure to event geography:

- **CloudFront (CDN)** already solves most of the geographic-latency problem by caching static assets at edge locations nationwide, without duplicating the entire backend per region
- **Ticket inventory needs strong consistency** — two regions independently accepting a purchase for the same seat is a real overselling risk. Keeping the transactional core in a single region avoids a genuinely hard distributed-systems problem (cross-region locking or reconciliation)
- **Multi-region is a disaster-recovery decision, not a geography-matching one** — you'd adopt it if a full regional outage were unacceptable to the business, independent of where any given event is happening

## 7. What Changes at 10x Scale

If steady-state traffic were 10x larger, I would reconsider:
- **Caching layer (ElastiCache/Redis)** in front of the database to reduce read load during spikes
- **CDN (CloudFront)** for static assets, reducing origin load entirely for a large fraction of requests
- **Database read replicas** to separate read-heavy browsing traffic from write-heavy purchase transactions
- **Multi-region active-passive** for disaster recovery, given the business impact of an outage during a major on-sale would be substantial at that scale
