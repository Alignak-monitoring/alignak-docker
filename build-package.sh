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
   git tag | grep -q "$1"
}

build_package_deb(){
    [[ ! -d $SRC_DIR/alignak-packaging/$PACKAGE/manpages ]] && cp $SRC_DIR/alignak-packaging/$PACKAGE/manpages $SRC_DIR/$PACKAGE
    [[ ! -d $SRC_DIR/alignak-packaging/$PACKAGE/systemd ]] && cp $SRC_DIR/alignak-packaging/$PACKAGE/systemd $SRC_DIR/$PACKAGE
    cp -r $SRC_DIR/alignak-packaging/$PACKAGE/debian $SRC_DIR/$PACKAGE  # This one is required

    VERSION=$(awk -F'\(?\-?' "/$PACKAGE/ {print $2}" $SRC_DIR/$PACKAGE/debian/changelog | head -1)
    if is_git_tag $1; then 
        # We only create a "current" version for upstream build
        cd $SRC_DIR/$PACKAGE
        RELEASE=$(git log -1  --format=%ct.%h)
        cd ../
        sed -i "s/-\([0-9]\+\))/-\1.$RELEASE)/g" $SRC_DIR/$PACKAGE/debian/changelog
    else
        sed -i "s/-\([0-9]\+\))/-\1~$CODENAME)/g" $SRC_DIR/$PACKAGE/debian/changelog
    fi
    tar -czf $PACKAGE_$VERSION.orig.tar.gz $PACKAGE
    cd $SRC_DIR/$PACKAGE
    dpkg-buildpackage
    mv ../$PACKAGE*.deb $OUT_DIR

    #TODO add lintian and grep W|E to count them
}

build_package_rpm(){
    [[ ! -d $SRC_DIR/alignak-packaging/$PACKAGE/manpages ]] && cp $SRC_DIR/alignak-packaging/$PACKAGE/manpages $SRC_DIR/$PACKAGE
    [[ ! -d $SRC_DIR/alignak-packaging/$PACKAGE/systemd ]] && cp $SRC_DIR/alignak-packaging/$PACKAGE/systemd $SRC_DIR/$PACKAGE
    cp -r $SRC_DIR/alignak-packaging/$PACKAGE/$PACKAGE.spec $SRC_DIR/$PACKAGE

    VERSION=$(awk '/Version/ {print $2}' $SRC_DIR/alignak-packaging/$PACKAGE.spec)
    if is_git_tag $1; then
        # We only create a "current" version for upstream build
        cd $PACKAGE
        RELEASE=$(git log -1  --format=%ct_%h)
        cd ../
        sed -i "s/\(Release:.*\)$/\1_$RELEASE/g" $SRC_DIR/alignak-packaging/$PACKAGE.spec
    fi
    mkdir -p ~/rpmbuild/SOURCES
    tar -czf ~/rpmbuild/SOURCES/$PACKAGE-$VERSION.tar.gz $PACKAGE
    rpmbuild -ba  $SRC_DIR/alignak-packaging/$PACKAGE.spec
    rm -rf ~/rpmbuild/RPMS/x86_64/*debuginfo*.rpm
    new_name=$(basename ~/rpmbuild/RPMS/x86_64/*.rpm | sed "s/\(.*\).x86_64.rpm/\1.$CODENAME.x86_64.rpm/g")
    mv ~/rpmbuild/RPMS/x86_64/*.rpm $OUT_DIR/$new_name

    #TODO add rpmlint and grep W|E to count them
}

prepare_upstream(){
    cd  $SRC_DIR/alignak-packaging/
    git fetch origin
    git checkout -f origin/master -B master
    cd  $SRC_DIR/$PACKAGE
    git fetch origin
    git checkout -f origin/develop -B develop

}

prepare_tag(){
    cd $SRC_DIR/alignak-packaging/
    git fetch origin
    if is_git_tag $1; then
      git checkout $1 -B v-$1
    elif [[ "$1" == "develop" ]]; then
      # We have no develop on packaging
      git checkout -f origin/master -B master
    else
      git checkout -f origin/$1 -B $1
    fi

    cd $SRC_DIR/$PACKAGE
    git fetch origin
    if is_git_tag $1; then
      git checkout $1 -B v-$1
    else
      git checkout -f origin/$1 -B $1
    fi

}

# We have a global variable TAG and PACKAGE
SYSTEMD_FILES=${SYSTEMD_FILES-1}  # By default we include systemd files
DISTRO=$(get_distro)
VERSION=$(get_version)
CODENAME=$(get_codename)
SRC_DIR=/root/src
OUT_DIR=/root/build-dir/${DISTRO}_${VERSION}
mkdir -p $OUT_DIR

ALIGNAK_GIT="https://github.com/Alignak-monitoring"
ALIGNAK_CRONTRIB_GIT="https://github.com/Alignak-monitoring-contrib"

[[ ! -d $SRC_DIR/alignak-packaging ]] && git clone $ALIGNAK_GIT/alignak-packaging.git $SRC_DIR/alignak-packaging

if [[ ! -d $SRC_DIR/$PACKAGE ]]; then
    if [[ $PACKAGE == "alignak" ]]; then
        git clone $ALIGNAK_GIT/alignak.git $SRC_DIR/alignak
    else
        git clone $ALIGNAK_CRONTRIB_GIT/$PACKAGE $SRC_DIR/$PACKAGE
    fi
fi


prepare_tag $TAG

case $DISTRO in
    debian|ubuntu)
        build_package_deb $TAG
        ;;
    fedora|centos|redhat)
        build_package_rpm $TAG
        ;;
    *)
        exit 1
        ;;
esac
