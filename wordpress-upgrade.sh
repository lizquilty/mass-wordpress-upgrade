#!/bin/bash
# Written by Liz Quilty ( liz@rimuhosting.com )
# feel free to pass it out, just keep my name on it for fame purposes :)
# run it as root
# bash wordpress-ugrade.sh
# Version 1.6 - making curl ignore SSL errors (wordpress.com has broken SSL atm) and follow redirects - fixes a number of bugs
# version 1.5 - Adding in plugins and theme updates, bug fixes, adding on cron checks
# version 1.4 - pull latest version via wordpres api, new --path option and automatic check for default paths by http://dropdeaddick.com/ 
# version 1.3 - keeping the permissions so that the web user can write to things ok
# Version 1.2 - Patched for better portability by http://twitter.com/valthonis


usercheck() {
if [ $(id -u) != "0" ]; then
          echo "You need to run this script as root."
          exit 1
fi

}

path() {
# Usually this is /var/www or /home. You can set your own path 
# do not set it to be / because then it will also find your 'backups' and possibly overwrite them
if [ -z "$1" ]; then
     if [ -d "/var/www" ] || [ -d "/home" ]; then
           if [ -d "/var/www" ]; then
                 dir1="/var/www"
           fi
           if [ -d "/home" ]; then
                  dir2="/home"
           fi
    fi
     FINDDIR="$dir1 $dir2"
elif [ -d "$1" ]; then
        FINDDIR="$1"
else
  echo "no valid directory found!"
  exit 1
fi
}

checkdeps() {

DEPSTOINSTALL='curl zip'
NEEDSINSTALL=""

for PKGSTOINSTALL in $DEPSTOINSTALL ; do
  if ! command -v $PKGSTOINSTALL &> /dev/null ; then
	NEEDSINSTALL="$NEEDSINSTALL $PKGSTOINSTALL"
  fi
done

  if [[ ! -z "$NEEDSINSTALL" ]]; then
	echo -e "$NEEDSINSTALL not installed, Install? (y/n) \c"
	read REPLY
	if [[ "$REPLY" = "y" ]]; then
	      # Debian based
	      if  command -v dpkg &> /dev/null; then
		apt-get install $NEEDSINSTALL 
	      # RPM based
	      elif command -v rpm &> /dev/null; then
		yum install $NEEDSINSTALL
	      else
		echo "Your distro is not supported!"
		exit 1
	      fi               
    
	  fi
  fi

}

  

version() {
# This is the version, it is pulled from wordpress. swap comment/uncomment variables CURRENT_VER to manually set
# CURRENT_VER="3.4.2"
CURRENT_VER=`curl -s http://api.wordpress.org/core/version-check/1.1/ |tail -1`
if [ -z "$CURRENT_VER" ]; then
        echo "could not get latest wordpress release, aborting!"
        exit 1
fi
CURRENT_MUVER="2.9.2"
}

cron() {
wplist=$(find ${FINDDIR} -wholename "*wp-includes/version.php" )

for file in $wplist ; do
	wp_root=$(echo $file | sed s@wp-includes/version.php@@)
	wpmu=$(grep wpmu_version ${wp_root}wp-includes/version.php)
	if [ "${wpmu}" == "" ]; then
		thisis="Standard Wordpress";
		WPCURRENT_VER=$CURRENT_VER
		WP_URL=http://wordpress.org/latest.zip 
		your_ver=$( grep "wp_version = '*'" "$file" |cut -d "'" -f2)
	else
		thisis="Wordpress MultiUser - you should have upgraded this long back to normal wordpress!";
		exit
	fi
	if [ ${your_ver} !=  ${WPCURRENT_VER} ];then
		echo "You have version $your_ver ${thisis} located at $wp_root that needs updating to ${WPCURRENT_VER}"
	fi
done
}

main() {
wplist=$(find ${FINDDIR} -wholename "*wp-includes/version.php" )

for file in $wplist ; do
	wp_root=$(echo $file | sed s@wp-includes/version.php@@)
	wpmu=$(grep wpmu_version ${wp_root}wp-includes/version.php)
	if [ "${wpmu}" == "" ]; then
		thisis="Standard Wordpress";
		WPCURRENT_VER=$CURRENT_VER
		WP_URL=http://wordpress.org/latest.zip 
		your_ver=$( grep "wp_version = '*'" "$file" |cut -d "'" -f2)
	else
		thisis="Wordpress MultiUser - you should have upgraded this long back to normal wordpress!";
		exit
	fi
	if [ ${your_ver} !=  ${WPCURRENT_VER} ];then
		echo "You have version $your_ver ${thisis} located at $wp_root that needs updating to ${WPCURRENT_VER}"
		echo -n "Would you like me to upgrade it? [y/N] "
		read yn
		if [ "$yn" = "y" ];then
			echo "Upgrading $wp_root"
			mkdir -p /tmp/wpupgrade
			cd 	
			# need to get the wp-config.php for user/pass/sitename
            if [ -f "${wp_root}/wp-config.php" ]; then
			db_name=$(grep DB_NAME "${wp_root}/wp-config.php" | cut -f4 -d"'")
			db_user=$(grep DB_USER "${wp_root}/wp-config.php" | cut -f4 -d"'")
			db_pass=$(grep DB_PASSWORD "${wp_root}/wp-config.php" | cut -f4 -d"'")
			# we also need the table prefix; not all wp installations use the default!
			table_prefix=$(grep table_prefix "${wp_root}/wp-config.php" | cut -f2 -d"'")
            else
                echo No wp-config.php exists? looks like its not wordpress, or not complete
                exit 0
            fi
			echo Checking i can connect to the db, if so get and set sitename variable
			RESULT=$(mysqladmin -u ${db_user} -p${db_pass} ping)
			if [ "$RESULT" == "mysqld is alive" ]; then
				echo Database connects fine
				# the SQL queries have been modified to use the table prefix accordingly
				if [ "${wpmu}" == "" ]; then
					siteurl=`echo SELECT option_value FROM ${table_prefix}options WHERE option_name=\'siteurl\' LIMIT 1 | mysql -u ${db_user} -p${db_pass} ${db_name} | sed s/option_value//`
					echo Site URL is $siteurl
					clean_url=$(echo $siteurl| sed s@http://@@g)
				else
					clean_url=`echo SELECT domain FROM ${table_prefix}site WHERE id=\'1\' LIMIT 1 | mysql -u ${db_user} -p${db_pass} ${db_name} | sed s/^domain\ //`
					siteurl="http://${clean_url}"
				fi

				clean_url=${clean_url%/}
                echo Making backup at /root/wp_upgrade/${clean_url}.sql and /root/wp_upgrade/${clean_url}.zip \(you can delete these later\)
				# Consider using something other than the URL as the name of the backup files? Perhaps the site name?
				mkdir -p /root/wp_upgrade/${clean_url}
				mysqldump -u ${db_user} -p${db_pass} ${db_name} > /root/wp_upgrade/${clean_url}.sql &&
				zip -qr /root/wp_upgrade/${clean_url}.zip ${wp_root} &&
				echo -n Checking we have latest wordress ...
				rm -rf /tmp/wpupgrade/latest.zip
				rm -rf /tmp/wpupgrade/wordpress
				# WP doesn't always come down as latest.zip, so let's make sure we save it as such
				curl -L -k -s -o latest.zip $WP_URL &&
				echo Unzipping ...
				unzip -oq latest.zip &&
				#getting the original owner permissions
				orig_perm=$(stat -c '%U:%G' $wp_root/wp-content/)
				stat -c '%U:%G' $wp_root/wp-content/

				alias cp=cp #some distros have cp aliased to cp -i which asks before each overwrite
				echo Setting up maintenance mode
				touch $wp_root/.maintenance
				echo Copying files over ...
				if [ "${wpmu}" == "" ]; then
					cp -a wordpress/* $wp_root/ 
				else
					cp -a wordpress-mu/* $wp_root/ 
				fi
				# this is probably not so secure ..
				echo Upgrading plugins
				rm -rf /tmp/plugupdate.txt 
				pluglist=$(find $wp_root/wp-content/plugins/ -maxdepth 1 -type d | sed s@$wp_root/wp-content/plugins/@@)
				for plugname in $pluglist ; do curl -L -k -s http://api.wordpress.org/plugins/info/1.0/$plugname.xml |grep download_link | cut -c40- | sed s/\].*// >>/tmp/plugupdate.txt ; done
				for file in $(cat /tmp/plugupdate.txt) ; do curl -L -k -s -o /tmp/tmp.zip $file ;unzip -qq -o /tmp/tmp.zip -d $wp_root/wp-content/plugins/ ; rm /tmp/tmp.zip ; done
				
				echo Upgrading themes
				rm -rf /tmp/themeupdate.txt 
				themelist=$(find $wp_root/wp-content/themes/ -maxdepth 1 -type d | sed s@$wp_root/wp-content/themes/@@)
				for themename in $themelist ; do numchars=$(echo $themename | wc -c) ;numchars=$(($numchars-1)); curl -L -k -s -d 'action=theme_information&request=O:8:"stdClass":1:{s:4:"slug";s:'$numchars':"'$themename'";}'  http://api.wordpress.org/themes/info/1.0/ |sed -n 's|.*http\(.*\)zip.*|http\1zip\n|p' >>/tmp/themeupdate.txt ; done
				for file in $(cat /tmp/themeupdate.txt) ; do curl -L -k -s -o /tmp/tmp.zip $file ;unzip -qq -o /tmp/tmp.zip -d $wp_root/wp-content/themes/ ; rm /tmp/tmp.zip ; done
				#// twentyten
				
				
				#chmod 777 $wp_root/wp-content/plugins
				#chmod 777 $wp_root/wp-content/themes
				echo Changing permissions to $orig_perm
				/bin/chown -R $orig_perm $wp_root
				
				#echo You may need to go to $siteurl/wp-admin/upgrade.php to complete the upgrade
				echo Doing the database upgrade with curl -L -k -s -o /tmp/debug $siteurl/wp-admin/upgrade.php?step=1
				# for some reason this occasionally fails, so we will do it twice to be sure. DB Upgrade is required with this version
				curl -s -o /tmp/debug $siteurl/wp-admin/upgrade.php?step=1
				curl -s -o /tmp/debug $siteurl/wp-admin/upgrade.php?step=1
				#echo Cleaning up
				#rm -rf /tmp/wpupgrade/
				echo Going back to normal mode
				rm $wp_root/.maintenance
			else
				echo "Something went wrong, aborting this uppgrade. Please do this site manually"	
			fi

		else
			echo "Leaving $wp_root alone as requested"
		fi
	else
		echo "Located wordpress at $wp_root - Up to date, nothing needs doing"
	fi
done

#check if cpanel is installed and correct public_html perms
if [ -e "/usr/local/cpanel/cpanel" ]; then
       /scripts/chownpublichtmls
fi

#echo Any backups are located at /root/wp_upgrade/
}

help() {
echo "Usage: wordpress-ugrade.sh [--path directory]"
echo "--path  :specify directory other than /var/www or /home"
echo "--cron  :specify directory other than /var/www or /home"
echo "        Do not set it to be / because then it will also find your 'backups' and possibly overwrite them"
}

case "$1" in
-h|-help|--help)
        usercheck
        help
        ;;
-c|-cron|--cron)
	usercheck
	path $2
	checkdeps
	version
        cron
        ;;
        
-p|-path|--path)
        usercheck
        path $2
        checkdeps
        version
        main
        ;;
*)
        usercheck
        path
        checkdeps
        version
        main
        ;;
esac
