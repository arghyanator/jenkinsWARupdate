#Get token after authenticating
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
echo "Generating expiring token...validity 10 minutes"
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
TOKEN=$(curl -s -k -u ${APIUSER}:${APIPASSWORD} -i -X GET http://localhost:5000/api/token |grep token | sed 's/"//g;s/token//g;s/://g;s/[[:blank:]]//g')
echo ${TOKEN}
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
echo "Upgrading Jenkins WAR to requested with the security token"
echo "it takes 5 to 10 Minutes --"
echo "output is shown at the end"
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
curl -s -k -u ${TOKEN}:unused -i "http://localhost:5000/api/runupgrade?warversion=$WARFILEVERSION"
