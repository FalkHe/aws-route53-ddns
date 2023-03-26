# aws-route53-ddns

Simple script to update an AWS Route53 ResourceRecord. For DDNS prupose.

Fetches the current public IP via ipify.org and pushes it via aws-cli to Route53.

Usage:
1. install `aws-cli`, `curl` & `dig`
2. configure your aws cli profile with sufficient access rights
3. put everything in .env (see .env.dist)
4. run ./aws-route53-update.sh
5. be happy
