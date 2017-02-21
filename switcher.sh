#!/bin/bash
# Copyright: 2014.12.28 - 2015 v1.1
# Author: icersong
# Modified: 2015.09.29


# ================================================================
scriptfile=${0##*/}
scriptname=${scriptfile%.*}
script_ext=${scriptfile##*.}
scriptpath=$(cd `dirname $0`; pwd)
# echo scriptfile: $scriptfile
# echo scriptname: $scriptname
# echo script_ext: $script_ext
# echo scriptpath: $scriptpath


# ================================================================
# script config
scriptconf="$scriptpath/${scriptname}.cfg"
echo scriptconf: $scriptconf
if [ ! -f "$scriptconf" ]; then
    echo "Error! Cofnig file '$scriptconf' not exists."
    exit
fi


# parse script config file
for line in  `cat $scriptconf`
do
    if [ "$line" == "" ] || [ "${line:0:1}" == "#" ] || [ "${line:0:1}" == ";" ] ; then
        continue
    fi
    name=${line%=*}
    text=${line##*=}
    if [ -z "$name" ]; then
        continue
    fi

    eval ${name}="$text"
done


# config path
if [ -z "$config_path" ] || [ "${config_path:0:1}" != "/" ]; then
    config_path="$scriptpath/$config_path"
fi
if [ ! -z "$config_path" ] && [ "${config_path:0:1}" != "/" ]; then
    config_path="${config_path%/}"
fi
if [ ! -d "$config_path" ]; then
    echo "Error! Project configs path '$config_path' not exists."
    exit
fi


echo config_path: "${config_path}"
echo apache_temp: "${apache_temp}"
echo apache_conf: "${apache_conf}"
echo apache_user: "${apache_user}"
echo apache_group: "${apache_group}"
echo python_venv: "${python_venv}"
echo python_home: "${python_home}"
echo python_path: "${python_path}"


# ================================================================
# project config select
# lst=$(ls "$config_path/"*.project)
# lst=`ls -w ${config_path}/*.project`
lst=`ls ${config_path}/*.project`
idx=1
for line in $lst
do
    name=${line##*/}
    echo "${idx}. ${name%.*}"
    idx=$(($idx+1))
done
read -p "请输入要切换的项目编号或名称:" input
idx=1
for line in $lst
do
    name=${line##*/}
    if [ "$idx" == "$input" ] || [ "${name%.*}" == "$input" ]; then
        selected=$line
        break
    fi
    idx=$(($idx+1))
done
if [ -z "$selected" ]; then
    echo "None selected!"
    exit
fi
echo Selected: ${idx}. ${name%.*} ${selected}


# ================================================================
# switch proejct
# load project config
for line in  `cat $selected`
do
    if [ "$line" == "" ] || [ "${line:0:1}" == "#" ] || [ "${line:0:1}" == ";" ] ; then
        continue
    fi
    name=${line%=*}
    text=${line##*=}
    if [ -z "$name" ]; then
        continue
    fi
    echo ${line} ${line:0:1}
    eval ${name}="$text"
done

codepath="${code_path%/}"
codeconf="${codepath}/${code_conf}"
urlalias="${home_alias%/}"
wsgipath="${wsgi_alias%/}"
wsgipath="/${wsgipath#/}"
wsgifile="${codepath}/${wsgi_file}"
conffile="${selected%.*}.cfg"

echo urlalias: $urlalias
echo wsgipath: $urlalias
echo wsgifile: $wsgifile
echo codepath: $codepath
echo codeconf: $codeconf

# ================================================================
# check config

# check code config file
if [ -f "${conffile}" ]; then
    echo "conffile: $conffile [OK]"
else
    echo "conffile: $conffile [NOT EXISTS]"
fi

# check code path
if [ -d "${codepath}" ]; then
    echo "code path: $codepath [OK]"
else
    echo "Error, Code path '$codepath' not exists."
    exit;
fi

if [ -f "${conffile}" ]; then
    if [ -d "${codeconf%/*}" ]; then
        echo "conf path: ${codeconf%/*} [OK]"
    else
        echo "Error, Code conf path '${codeconf%/*}' not exists."
    fi
fi

# check apache config file exists
if [ -d "${apache_conf%/*}" ]; then
    echo "apache config path: ${apache_conf%/*} [OK]"
else
    echo "Error, Apache config path '${apache_conf%/*}' not exists."
    exit;
fi


# ================================================================
# copy code config file
if [ -f "${conffile}" ]; then
    echo "copy ${conffile}"
    echo "  -> ${codeconf}"
    cp -f "${conffile}" "${codeconf}"
fi


# ================================================================
# change apache python config
echo "create ${apache_conf}"

# ----------------------------------------------------------------
# make new apache config
tmp=`mktemp /tmp/apache.conf.XXX`
cat $config_path/\@multi-flask-apps.conf>$tmp
# echo tempfile: $tmp
cat>>$tmp<<EOF

RewriteRule ^(/?)$ ${urlalias}/index.html [R]
RewriteRule ^(${urlalias}/?)$ ${urlalias}/index.html [R]

Alias "${urlalias}/fonts" "$codepath/fonts"
Alias "${urlalias}/styles" "$codepath/styles"
Alias "${urlalias}/index.html" "$codepath/index.html"
Alias "${urlalias}/revision" "$codepath/revision"

WSGIPythonHome /home/icersong/.virtualenvs/som-py2.7/
WSGIPythonPath /home/icersong/.virtualenvs/som-py2.7/lib/python2.7/site-packages
WSGIDaemonProcess app-wf2 \\
        python-eggs=/tmp/python-eggs \\
        python-home=${python_home} \\
        python-path=${python_path} \\
        user=${apache_user} group=${apache_group} \\
        processes=1 threads=9 display-name=%{GROUP}-wf2
WSGIScriptAlias ${wsgipath} $wsgifile
<Location "${codepath}">
    WSGIProcessGroup app-wf2
    WSGIApplicationGroup %{GLOBAL}
    Options FollowSymlinks
    Require all granted
</Location>
<Directory "${codepath}">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
    Order allow,deny
    Allow from all
</Directory>
EOF
# ----------------------------------------------------------------

# copy apache config file
sudo mv -f "$tmp" "${apache_conf}"
sudo chmod 644 "${apache_conf}"
# sudo chown root:wheel "${apache_conf}"


# ================================================================
# restart apache
echo "restart apache."
sudo apachectl -k restart
# expect << EOF
# spawn sudo apachectl restart
# expect "Password:"
# send "\ \n"
# interact;
# EOF

echo "complete."
