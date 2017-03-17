#!/bin/bash

get_distro(){
    DISTRO=$(lsb_release -i | cut -f 2 | tr [A-Z] [a-z])

    if [[ $? -ne 0 ]]; then
       DISTRO=$(head -1 /etc/issue | cut -f 1 -d " " | tr [A-Z] [a-z])
    fi

    echo $DISTRO
}

get_version(){
    VERSION=$(lsb_release -r |  cut -f 2 | cut -f 1 -d ".")

    if [[ $? -ne 0 ]]; then
       if [[ ! -f /etc/redhat-release  ]]; then
           VERSION=$(head -1 /etc/issue | cut -f 3 -d " " )
       else
           VERSION=$(cat /etc/redhat-release | cut -f 4 -d " " | cut -f 1 -d ".")
       fi
    fi

    echo $VERSION
}

get_codename(){
    CODENAME=$(lsb_release -c | cut -f 2)
    ret=$?

    if [[ "$CODENAME" == "Core" ]]; then
       CODENAME="el"$VERSION
    elif [[ $ret -ne 0 ]]; then
       CODENAME=$(grep "VERSION="  /etc/os-release | sed 's/.*(\([a-z]\+\))"/\1/g')
    fi

    echo $CODENAME

}

is_git_tag(){
  [[ "$1" != "" ]] &&  git tag | grep -q "$1"
}

ensure_https_remote(){
  cd $1  # Example $SRC_DIR/alignak-packaging
  git config --global url."https://".insteadOf git://
}


build_package_deb(){
    cd $SRC_DIR
    [[ -d $SRC_DIR/alignak-packaging/$PACKAGE/manpages ]] && cp -r $SRC_DIR/alignak-packaging/$PACKAGE/manpages $SRC_DIR/$PACKAGE
    [[ -d $SRC_DIR/alignak-packaging/$PACKAGE/systemd ]] && cp -r $SRC_DIR/alignak-packaging/$PACKAGE/systemd $SRC_DIR/$PACKAGE
    # For dep package that ship non existing dependencies
    [[ -d $SRC_DIR/alignak-packaging/$PACKAGE/vendor ]] && cp -r $SRC_DIR/alignak-packaging/$PACKAGE/vendor $SRC_DIR/$PACKAGE
    cp -r $SRC_DIR/alignak-packaging/$PACKAGE/debian $SRC_DIR/$PACKAGE  # This one is required

    VERSION=$(awk -F'\(?\-?' "/$PACKAGE/ {print \$2}" $SRC_DIR/$PACKAGE/debian/changelog | head -1)
    if is_git_tag $1; then 
        # We only create a "current" version for upstream build
        cd $SRC_DIR/$PACKAGE
        RELEASE=$(git log -1  --format=%ct.%h)
        cd ../
        sed -i "s/-\([0-9]\+\))/-\1.$RELEASE)/g" $SRC_DIR/$PACKAGE/debian/changelog
    else
        sed -i "s/-\([0-9]\+\))/-\1~$CODENAME)/g" $SRC_DIR/$PACKAGE/debian/changelog
    fi
    tar -czf ${PACKAGE}_${VERSION}.orig.tar.gz $PACKAGE
    cd $SRC_DIR/$PACKAGE
    dpkg-buildpackage
    mv ../$PACKAGE*.deb $OUT_DIR

    #TODO add lintian and grep W|E to count them
}

build_package_rpm(){
    cd $SRC_DIR
    [[ -d $SRC_DIR/alignak-packaging/$PACKAGE/manpages ]] && cp -r $SRC_DIR/alignak-packaging/$PACKAGE/manpages $SRC_DIR/$PACKAGE
    [[ -d $SRC_DIR/alignak-packaging/$PACKAGE/systemd ]] && cp -r $SRC_DIR/alignak-packaging/$PACKAGE/systemd $SRC_DIR/$PACKAGE
    # For dep package that ship non existing dependencies
    [[ -d $SRC_DIR/alignak-packaging/$PACKAGE/vendor ]] && cp -r $SRC_DIR/alignak-packaging/$PACKAGE/vendor /root/rpmbuild/SOURCES/
    cp -r $SRC_DIR/alignak-packaging/$PACKAGE/$PACKAGE.spec $SRC_DIR/$PACKAGE

    VERSION=$(awk '/Version/ {print $2}' $SRC_DIR/alignak-packaging/$PACKAGE/$PACKAGE.spec)
    if is_git_tag $1; then
        # We only create a "current" version for upstream build
        cd $PACKAGE
        RELEASE=$(git log -1  --format=%ct_%h)
        cd ../
        sed -i "s/\(Release:.*\)$/\1_$RELEASE/g" $SRC_DIR/alignak-packaging/$PACKAGE/$PACKAGE.spec
    fi
    mkdir -p ~/rpmbuild/SOURCES
    tar -czf ~/rpmbuild/SOURCES/${PACKAGE}-${VERSION}.tar.gz $PACKAGE
    rpmbuild -ba  $SRC_DIR/alignak-packaging/$PACKAGE/$PACKAGE.spec
    rm -rf ~/rpmbuild/RPMS/x86_64/*debuginfo*.rpm
    for rpm_file in ~/rpmbuild/RPMS/x86_64/*.rpm; do
        new_name=$(basename $rpm_file | sed "s/\(.*\).x86_64.rpm/\1.$CODENAME.x86_64.rpm/g")
        mv $rpm_file $OUT_DIR/$new_name
    done

    #TODO add rpmlint and grep W|E to count them
}

prepare_tag(){
    cd $SRC_DIR/alignak-packaging/
    git fetch origin
    if is_git_tag $2; then
      git checkout $2 -B v-$2
    elif [[ "$2" != "" ]]; then
      git checkout -f origin/$2 -B $2
    else
      echo "Not checking out new branch as tag is empty"
    fi

    cd $SRC_DIR/$PACKAGE
    git fetch origin
    if is_git_tag $1; then
      git checkout $1 -B v-$1
    elif [[ "$2" != "" ]]; then
      git checkout -f origin/$1 -B $1
    else
      echo "Not checking out new branch as tag is empty"
    fi

}

# We have a global variable TAG_SRC, TAG_PACKAGING and PACKAGE
SYSTEMD_FILES=${SYSTEMD_FILES-1}  # By default we include systemd files
DISTRO=$(get_distro)
VERSION=$(get_version)
CODENAME=$(get_codename)
REPOS_DIR=/root/repos
SRC_DIR=/root/src
OUT_DIR=/root/build-dir/${DISTRO}_${VERSION}

ALIGNAK_GIT="https://github.com/Alignak-monitoring"
ALIGNAK_CRONTRIB_GIT="https://github.com/Alignak-monitoring-contrib"


[[ -d $SRC_DIR ]] && rm -rf $SRC_DIR/* || mkdir -p $SRC_DIR

mkdir -p $OUT_DIR

if [[ -d $REPOS_DIR/alignak-packaging ]]; then
    cp -r $REPOS_DIR/alignak-packaging $SRC_DIR/
    ensure_https_remote $SRC_DIR/alignak-packaging
else
    git clone $ALIGNAK_GIT/alignak-packaging.git $SRC_DIR/alignak-packaging
fi

if [[ -d $REPOS_DIR/$PACKAGE ]]; then
    cp -r $REPOS_DIR/$PACKAGE $SRC_DIR/
    ensure_https_remote $SRC_DIR/$PACKAGE
else
    if [[ $PACKAGE == "alignak" ]]; then
        git clone $ALIGNAK_GIT/alignak.git $SRC_DIR/alignak
    else
        git clone $ALIGNAK_CRONTRIB_GIT/$PACKAGE.git $SRC_DIR/$PACKAGE
    fi
fi

prepare_tag $TAG_SRC $TAG_PACKAGING

case $DISTRO in
    debian|ubuntu)
        build_package_deb $TAG_SRC
        ;;
    fedora|centos|redhat)
        build_package_rpm $TAG_SRC
        ;;
    *)
        exit 1
        ;;
esac
