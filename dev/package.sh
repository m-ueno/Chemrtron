#!/bin/sh

set -x

ROOT=$(cd $(dirname $0)/..; pwd)
cd $ROOT

version=$(cat VERSION);
echo "Create version: v$version"

echo "UPDATE CONTRIBUTOR LIST"
curl https://api.github.com/repos/cho45/Chemrtron/contributors | \
	node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8')).map(x => '@' + x.login).filter(x => x !== '@cho45').join(', '));" \
	> CONTRIBUTORS

rm -r build
mkdir -p build/releases

### OS X

if [ x$SKIP_OSX != x1 ]; then
	electron-packager . Chemr \
		--icon=assets/osx/icon.icns \
		--app-bundle-id=net.lowreal.Chemr \
		--helper-bundle-id=net.lowreal.ChemrHelper \
		--out build \
		--platform=mas \
		--arch=x64 \
		--version=0.34.3 \
		--ignore=build \
		--app-version=$version

	cd build/Chemr-mas-x64

	ruby -i -anal -e 'puts gsub(/com.github.electron/, "net.lowreal.Chemr").gsub(/Electron/, "Chemr")' Chemr.app/Contents/Frameworks/Chemr\ Helper\ EH.app/Contents/Info.plist
	ruby -i -anal -e 'puts gsub(/com.github.electron/, "net.lowreal.Chemr").gsub(/Electron/, "Chemr")' Chemr.app/Contents/Frameworks/Chemr\ Helper\ NP.app/Contents/Info.plist

	cd $ROOT

	# Name of your app.
	APP="Chemr"
	# The path of you app to sign.
	APP_PATH="build/Chemr-mas-x64/Chemr.app"
	# The path to the location you want to put the signed package.
	RESULT_PATH="build/releases/Chemr.pkg"
	# The name of certificates you requested.
	APP_KEY="3rd Party Mac Developer Application: Hirofumi Watanabe (877L5ULMT9)"
	INSTALLER_KEY="3rd Party Mac Developer Installer: Hirofumi Watanabe (877L5ULMT9)"

	FRAMEWORKS_PATH="$APP_PATH/Contents/Frameworks"

	if [ x$SIGN == x1 ]; then
		codesign --deep -fs "$APP_KEY" --entitlements dev/child.plist "$FRAMEWORKS_PATH/Electron Framework.framework/Libraries/libnode.dylib"
		codesign --deep -fs "$APP_KEY" --entitlements dev/child.plist "$FRAMEWORKS_PATH/Electron Framework.framework/Electron Framework"
		codesign --deep -fs "$APP_KEY" --entitlements dev/child.plist "$FRAMEWORKS_PATH/Electron Framework.framework/"
		codesign --deep -fs "$APP_KEY" --entitlements dev/child.plist "$FRAMEWORKS_PATH/$APP Helper.app/"
		codesign --deep -fs "$APP_KEY" --entitlements dev/child.plist "$FRAMEWORKS_PATH/$APP Helper EH.app/"
		codesign --deep -fs "$APP_KEY" --entitlements dev/child.plist "$FRAMEWORKS_PATH/$APP Helper NP.app/"
		codesign  -fs "$APP_KEY" --entitlements dev/parent.plist "$APP_PATH"
		productbuild --component "$APP_PATH" /Applications --sign "$INSTALLER_KEY" "$RESULT_PATH"
	else
		if [ x$SANDBOX == x0 ]; then
			electron-builder \
				build/Chemr-mas-x64/Chemr.app \
				--platform=osx \
				--out=build/releases \
				--config=installer.json
		else
			codesign --deep -fs - --entitlements dev/child.plist "$FRAMEWORKS_PATH/Electron Framework.framework/Libraries/libnode.dylib"
			codesign --deep -fs - --entitlements dev/child.plist "$FRAMEWORKS_PATH/Electron Framework.framework/Electron Framework"
			codesign --deep -fs - --entitlements dev/child.plist "$FRAMEWORKS_PATH/Electron Framework.framework/"
			codesign --deep -fs - --entitlements dev/child.plist "$FRAMEWORKS_PATH/$APP Helper.app/"
			codesign --deep -fs - --entitlements dev/child.plist "$FRAMEWORKS_PATH/$APP Helper EH.app/"
			codesign --deep -fs - --entitlements dev/child.plist "$FRAMEWORKS_PATH/$APP Helper NP.app/"
			codesign  -fs - --entitlements dev/parent.plist "$APP_PATH"
			productbuild --component "$APP_PATH" /Applications "$RESULT_PATH"
		fi
	fi
fi


### Windows

if [ x$SKIP_WIN != x1 ]; then
	electron-packager . Chemr \
		--out build \
		--icon=assets/win/icon.ico \
		--platform=win32 \
		--arch=ia32 \
		--version=0.34.3 \
		--version-string.ProductName="Chemr" \
		--version-string.ProductVersion="$version" \
		--ignore=build \
		--app-version=$version

	cp dev/Chemr.exe.manifest build/Chemr-win32-ia32/
	cp dev/installer.nsi.tpl node_modules/electron-builder/templates/installer.nsi.tpl

	./node_modules/.bin/electron-builder \
		build/Chemr-win32-ia32 \
		--platform=win \
		--out=build/releases \
		--config=installer.json
fi
