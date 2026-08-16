using a public EC2 with elastiuc ip



# tools needed

- nginx
- git
- cert-bot # this will give me ssl certs


# check user data logs
```bash
# Main log - user-data output + cloud-init logs combined
sudo cat /var/log/cloud-init-output.log

# Just cloud-init's own process log (more verbose, less focused on your script output)
sudo cat /var/log/cloud-init.log
```