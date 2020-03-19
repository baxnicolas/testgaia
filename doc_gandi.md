# Gandi

## DNS Delegation

We explain here how you need to proceed
if you want to use your `Gandi main` domain with `AWS subdomains`.

Ex:

- `Main domain:` forge-demo.fr hosted at Gandi
- `Sub domain:` app-staging.env.forge-demo.fr hosted at AWS

Process:

- Go to `AWS Route53`, in your hosted zone, and look at the `NS record`
- Get the list of name servers: NS1, NS2, NS3 and NS4 (with the final dot)
- Go to `Gandi`, in forge-demo.fr domain name section
- Then go to DNS records section
- And create for DNS record:
    - Type: NS
    - Name: app-staging
    - value: NS[ID]

Congratulations, now DNS resolution for app-staging.env.forge-demo.fr should be "rooted"
to AWS name servers for resolution.
