#!/bin/bash
git submodule update --init --recursive
git submodule foreach git pull

VER_MAJOR=$(grep "#define MDB_VERSION_MAJOR.*[0-9]*" lmdb/libraries/liblmdb/lmdb.h | grep -o "[0-9]*")
VER_MINOR=$(grep "#define MDB_VERSION_MINOR.*[0-9]*" lmdb/libraries/liblmdb/lmdb.h | grep -o "[0-9]*")
VER_PATCH=$(grep "#define MDB_VERSION_PATCH.*[0-9]*" lmdb/libraries/liblmdb/lmdb.h | grep -o "[0-9]*")
VERSION=$(echo "${VER_MAJOR}.${VER_MINOR}.${VER_PATCH}")

#check if we already have an up-to-date tgz
if [ -f "build/LMDB.tgz" ]; then
    tar xzf build/LMDB.tgz LMDB.docset/meta.json
    OLD_VERSION=$(jq -r '.revision' LMDB.docset/meta.json)
    rm -r LMDB.docset
    if [ "$VERSION" = "$OLD_VERSION" ]; then
        echo "build/LMDB.tgz is up to date. Nothing to do."
        exit 1
    fi
fi

pushd ./lmdb/libraries/liblmdb/
#change doxygen config to fit our needs
sed -i.orig 's/GENERATE_DOCSET.*/GENERATE_DOCSET = YES/; s/DISABLE_INDEX.*/DISABLE_INDEX = YES/; s/SEARCHENGINE.*/SEARCHENGINE = NO/; s/GENERATE_TREEVIEW.*/GENERATE_TREEVIEW = NO/' Doxyfile
doxygen
mv ./Doxyfile{.orig,}
popd

#build doxygen2docset
mkdir -p ./doxygen2docset/build/
pushd ./doxygen2docset/build/
cmake ../ && make
popd

mkdir -p build
pushd build
../doxygen2docset/build/source/doxygen2docset --doxygen ../lmdb/libraries/liblmdb/html --docset ./
mv ./{org.doxygen.Project.docset,LMDB.docset}
cat <<EOF >LMDB.docset/meta.json
{
    "name": "LMDB",
    "revision": "$VERSION",
    "title": "LMDB"
}
EOF
cat <<EOF >LMDB.docset/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
<key>CFBundleIdentifier</key>
<string>lmdb</string>
<key>CFBundleName</key>
<string>LMDB</string>
<key>DocSetPlatformFamily</key>
<string>lmdb</string>
<key>isDashDocset</key>
<true/>
</dict>
</plist>
EOF

tar czf LMDB.{tgz,docset}
rm -r LMDB.docset

cat <<EOF >docset.json
{
    "name": "LMDB",
    "version": "$VERSION",
    "archive": "LMDB.tgz",
    "author": {
        "name": "$LMDB_DOCSET_AUTHOR",
        "link": "$LMDB_DOCSET_AUTHOR_LINK"
    },
    "aliases": ["Lightning Memory-Mapped Database Manager"]
}
EOF

cat <<EOF >README.md
# LMDB Docset For Dash
Hi, I'm [$LMDB_DOCSET_AUTHOR]($LMDB_DOCSET_AUTHOR_LINK) and I threw this docset thing together in an afternoon.  
The script I'm using can be found [here]($LMDB_DOCSET_SCRIPT_LINK). For usage, prerequisites, etc. see its README.  

The original docs are from the [LMDB source](https://github.com/LMDB/lmdb/tree/mdb.master/libraries/liblmdb) using doxygen. An online version is also available on [lmdb.tech](http://www.lmdb.tech/doc/index.html).

That is all. kthxbye.
EOF
popd
exit 0
