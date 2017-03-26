# wordpress-upgrade.sh 
http://blog.rimuhosting.com/2013/10/17/wordpress-upgrade-shell-script-plugins-themes-crontab-and-more/

This script is made to upgrade wordpress installs, themes, plugins via the command line. It also works well to check for any on a server, or in a cron to notify you when some are outdated.

Usage: 
```bash
./wordpress-upgrade.sh
./wordpress-upgrade.sh -c 
```

# restorewordpress.sh 
http://blog.rimuhosting.com/2013/08/21/how-to-restore-a-wordpress-site-after-hacks-or-exploits-in-10-steps/

A script used to restore an exploited wordpress. It moves the old DocumentRoot out of the way, downloads a fresh wordpress, fresh plugins and themes and then migrates uploads directory over.
You will still need to manually check wp-config.php and any custom themes

Usage: 
```bash
./restorewordpress.sh /path/to/wordpress
```

