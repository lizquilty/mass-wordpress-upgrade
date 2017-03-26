#!/bin/bash



usercheck() {
if [ $(id -u) != "0" ]; then
          echo "You need to run this script as root."
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



function FixDir  {
    wp_root="$1"
    if [ -f "$1/wp-config.php" ] && [ -f "$1/wp-includes/version.php" ] ;then
    DateStamp=$(date +%d-%b-%Y)
    bak_wp_root="${wp_root}-${DateStamp}/"
    
    orig_perm=$(stat -c '%U:%G' $wp_root/wp-content/)

    echo "Moving ${wp_root} ${bak_wp_root}"
    mv ${wp_root} ${bak_wp_root}
    curl -k -L -s -o /tmp/latest.zip http://wordpress.org/latest.zip
    cd /tmp/
    unzip -qq /tmp/latest.zip
    mv wordpress ${wp_root}
    cp ${bak_wp_root}/wp-config.php ${wp_root}/
    
    echo Upgrading plugins
        rm -rf /tmp/plugupdate.txt
        pluglist=$(find $bak_wp_root/wp-content/plugins/ -maxdepth 1 -type d | sed s@$bak_wp_root/wp-content/plugins/@@)
        for plugname in $pluglist ; do curl -k -L -s http://api.wordpress.org/plugins/info/1.0/$plugname.xml |grep download_link | cut -c40- | sed s/\].*// >>/tmp/plugupdate.txt ; done
        for file in $(cat /tmp/plugupdate.txt) ; do curl -k -L -s -o /tmp/tmp.zip $file ;unzip -qq -o /tmp/tmp.zip -d $wp_root/wp-content/plugins/ ; rm /tmp/tmp.zip ; done
 
        echo Upgrading themes
        rm -rf /tmp/themeupdate.txt
        themelist=$(find $bak_wp_root/wp-content/themes/ -maxdepth 1 -type d | sed s@$bak_wp_root/wp-content/themes/@@)
        for themename in $themelist ; do numchars=$(echo $themename | wc -c) ;numchars=$(($numchars-1)); curl -k -L -s -d 'action=theme_information&request=O:8:"stdClass":1:{s:4:"slug";s:'$numchars':"'$themename'";}'  http://api.wordpress.org/themes/info/1.0/ |sed -n 's|.*http\(.*\)zip.*|http\1zip\n|p' >>/tmp/themeupdate.txt ; done
        for file in $(cat /tmp/themeupdate.txt) ; do curl -k -L -s -o /tmp/tmp.zip $file ;unzip -qq -o /tmp/tmp.zip -d $wp_root/wp-content/themes/ ; rm /tmp/tmp.zip ; done

        echo Copying over .htaccess
        cp -a  ${bak_wp_root}/.htaccess ${wp_root}/.htaccess
              
        echo Copying over Uploads folder
        cp -a  ${bak_wp_root}/wp-content/uploads ${wp_root}/wp-content/uploads
        echo "Removing any .php .pl or other potential exploits from new uploads copy"
        find ${wp_root}/wp-content/uploads -type f -size +4096c -iname "*.php" -exec rm -rf {} \;
        find ${wp_root}/wp-content/uploads -type f -size +4096c -iname "*.pl" -exec rm -rf {} \;
        find ${wp_root}/wp-content/uploads -type f -size +4096c -iname "*.c" -exec rm -rf {} \;
        
        echo "Potentially hidden/bad directorys you may want to look into after this ...."
        echo
        find ${wp_root}/wp-content/uploads -type d -iname ".*" 
        echo 
        echo "It pays to  manually look at the files in the Uploads dir yourself to verify things"
        echo "Custom plugins or themes will not have been copied over"
        
        
        echo Changing permissions to $orig_perm
        /bin/chown -R $orig_perm $wp_root
        else 
        echo "$wp_root is not a wordpress directory"
        fi
        } 
        
if [ -d "$1" ];then
        usercheck
        checkdeps
        wp_root=$(echo $1 | sed 's:/$::')
	FixDir $wp_root
else

echo Usage: $0 /full/path/to/dir
fi
