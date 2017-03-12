Build a package
===============

::

  SRC_DIR=<SRC_DIR> DISTRO=<DISTRO> PACKAGE=<PACKAGE> TAG=<TAG> make package

+------------+-----------------+-------------------------------------+
| Variable   |     Default     |              Description            |
+============+=================+=====================================+
| PACKAGE    | alignak         | Package to build.                   |
|            |                 | Must match git repo name or         |
|            |                 | directory name (if mounted)         |
+------------+-----------------+-------------------------------------+
| TAG        | develop         | Branch or tag to build from.        |
|            |                 | If not building alignak, you        |
|            |                 | probably want to put master instead |
+------------+-----------------+-------------------------------------+
| DISTRO     | ubuntu14        | Distrubution to build the package.  |
|            | ubuntu16        | It must be one or several of the    |
|            | debian8         | default value. If multiple, use     |
|            | centos7         | double quotes around the list       |
+------------+-----------------+-------------------------------------+
| SRC_DIR    | $HOME/repos     | Source directory, mounted in docker |
|            |                 | If $SRC_DIR/$PACKAGE exists, it will|
|            |                 | use it as src. Else, git clone the  |
|            |                 | repository from github.             |
|            |                 | Caution : It will checkout master   |
|            |                 | uncommited change may be lost       |
|            |                 | It will also change some permission |
|            |                 | as checkout is made as root         |
+------------+-----------------+-------------------------------------+

The default command ::

  make package

will build alignak package for all supported GNU/Linux distributions

Builder images can be built locally or pulled from Docker Hub


Build Image
===========

::

  DISTRO=<DISTRO> make build

+------------+-----------------+-------------------------------------+
| Variable   |     Default     |              Description            |
+============+=================+=====================================+
| DISTRO     | ubuntu14        | Distrubution to build the package.  |
|            | ubuntu16        | It must be one or several of the    |
|            | debian8         | one in default value. If multiple,  |
|            | centos7         | use double quote around the list    |
+------------+-----------------+-------------------------------------+

The default command ::

  make build

will rebuild all docker images for all supported GNU/Linux distributions


