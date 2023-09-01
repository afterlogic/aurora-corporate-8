#!/bin/bash

# eval $(ssh-agent)
# ssh-add ~/.ssh/id_rsa

# trap 'echo "# $BASH_COMMAND";read' DEBUG

DIR=$(cd `dirname $0` && pwd)

update ()
{
    cd ${1}
    # printf "Module folder is "$(cd `dirname $0` && pwd)$NC"\n"

	git fetch origin
	
	HAS_REMOTE_VUE_BRANCH=`git show-branch remotes/origin/vue-mobile | grep -o vue-mobile | grep -m1 -o vue-mobile`
	
	if [ "${HAS_REMOTE_VUE_BRANCH}" = vue-mobile ]; then
		printf "${YELLOW}Reseting to ${NC}${BG_GREEN} vue-mobile ${NC}\n"
		ON_VUE_BRANCH=`git status | grep -o 'On branch vue-mobile'`
		if [ -z "$ON_VUE_BRANCH" ]; then
			HAS_LOCAL_VUE_BRANCH=`git show-branch vue-mobile | grep -o vue-mobile | grep -m1 -o vue-mobile`
			if [ -z "$HAS_LOCAL_VUE_BRANCH" ]; then
				git checkout vue-mobile
				git reset --hard origin/master
			else
				git checkout -b vue-mobile origin/vue-mobile
			fi
		fi
		git reset --hard origin/vue-mobile
	else
		printf "${YELLOW}Reseting to ${NC}${BG_RED} master ${NC}\n"
		git checkout master
		git reset --hard origin/master
	fi
}

BG_RED='\033[1;41m'
BG_YELLOW='\033[1;43m'
BG_GREEN='\033[1;42m'

RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color


printf "${YELLOW} Do ${RED}npm install${YELLOW} for main JS code and admin panel?${NC}(y/n) \n"
while true; do
	read -s -n 1 -p "" DO_NPM_INSTALL
	case $DO_NPM_INSTALL in
		[yn]* ) break;;
		* ) printf "${RED}Please answer y or n.${NC}\n";;
	esac
done

printf "${YELLOW} Do build ${RED}main static${YELLOW}?${NC}(y/n) \n"
while true; do
	read -s -n 1 -p "" DO_BUILD_STATIC
	case $DO_BUILD_STATIC in
		[yn]* ) break;;
		* ) printf "${RED}Please answer y or n.${NC}\n";;
	esac
done

printf "${YELLOW} Do ${RED}yarn install${YELLOW} for mobile app?${NC}(y/n) \n"
while true; do
	read -s -n 1 -p "" DO_NPM_INSTALL_MOBILE
	case $DO_NPM_INSTALL_MOBILE in
		[yn]* ) break;;
		* ) printf "${RED}Please answer y or n.${NC}\n";;
	esac
done

#List of modules that has vue-mobile branch
cd ${DIR}/modules

for dir in $(find . -name ".git")
do
	# echo ${dir%/*}
	moduleName=`echo ${dir%/*} | cut -c3-`

	printf $BG_GREEN"  "$moduleName"  "$NC"\n"

	INSTALLATION_PATH=${DIR}/modules/${moduleName}
	update $INSTALLATION_PATH

	echo ""
done

#Updating framework
printf $GREEN"Updadating "$YELLOW"System"$GREEN".\n"$NC
INSTALLATION_PATH=${DIR}/system/
update $INSTALLATION_PATH
printf ""

printf $GREEN"Updadating "$YELLOW"Dav"$GREEN".\n"$NC
INSTALLATION_PATH=${DIR}/vendor/afterlogic/dav
update $INSTALLATION_PATH
printf "\n\n"


printf "${BG_GREEN} Updating the database ${NC}\n"
${DIR}/system/bin/console migrate --no-interaction
printf "\n\n"


printf "${BG_GREEN} Clearing cache ${DIR}/data/cache ${NC}\n\n"
rm -r ${DIR}/data/cache
printf "\n\n"

cd ${DIR}

printf $GREEN"Building mobile app.\n"$NC
chmod +x builder.sh
# ./builder.sh -t npm-mobile
# ./builder.sh -t build-mobile
cd ${DIR}/modules/CoreMobileWebclient/vue-mobile/
if [ "${DO_NPM_INSTALL_MOBILE}" = "y" ]; then
	printf "${GREEN}Installing dependencies for mobile app.${NC}\n"
	yarn install
	echo ""
fi

yarn run build-production
cd ${DIR}
echo ""

if [ "${DO_NPM_INSTALL}" = "y" ]; then
	printf "${GREEN}Installing dependencies for main JS and admin panel.${NC}\n"
	./builder.sh -t npm
	echo ""
fi
if [ "${DO_BUILD_STATIC}" = "y" ]; then
	printf "${GREEN}Building common static files.${NC}\n"
	./builder.sh -t build
	echo ""
fi

