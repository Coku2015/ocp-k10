#! /bin/bash
contact_us=lei.wei@veeam.com

Press_Install(){
    echo ""
    echo -e "Press any key to continue...or Press Ctrl+c to cancel"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}
}

clearscreen(){
    local clear_flag=""
    clear_flag=$1
    if [[ ${clear_flag} == "clear" ]]; then
        clear
    fi
    echo ""
    echo "+-----------------------------------------------------------------+"
    echo "|                      1 key k10 demo script                      |"
    echo "+----------------------------------------------------------------+"
    echo "|   A tool to help you install k10 demo environment in 3 minutes  |"
    echo "+-----------------------------------------------------------------+"
    echo "|  Intro: ${contact_us}                           |"
    echo "+-----------------------------------------------------------------+"
    echo ""
}

Display_Selection(){
    def_Install_Select="1"
    echo -e "You have 6 options for your K10 installation."
    echo "1: Install K10 only"
    echo "2: Install K10 and PostgreSQL"
    echo "3: Install K10 and MySQL"
    echo "4: Install K10 and configure object storage"
    echo "5: Install K10/PostgreSQL/Object Storage"
    echo "6: Install K10/MySQL/Object Storage"
    echo "7: Uninstall everything."
    read -p "Enter your choice (1-7 or exit. default [${def_Install_Select}]): " Install_Select

    case "${Install_Select}" in
    1)
        echo
        echo -e "You will install K10."
        ;;
    2)
        echo
        echo -e "You will install K10 and PostgreSQL."
        ;;
    3)
        echo
        echo -e "You will install K10 and MySQL."
        ;;
    4)
        echo
        echo -e "You will install K10 and configure object storage."
        ;;
    5)
        echo
        echo -e "You will install K10/PostgreSQL/Object Storage."
        ;;
    6)
        echo
        echo -e "You will install K10/MySQL/Object Storage."
        ;;
    7)
        echo
        echo -e "You will destory everything."
        ;;
    [eE][xX][iI][tT])
        echo -e "You select <Exit>, shell exit now!"
        exit 1
        ;;
    *)
        echo
        echo -e "No input,You will install k10 only."
        Install_Select="${def_Install_Select}"
    esac
}

randstr(){
	index=0
	strRandomPass=""
	for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
	for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
	for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
	for i in {1..4}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
	echo $strRandomPass
}

check_k10_installed(){
    k10_installed_flag="$(kubectl get ns kasten-io &> /dev/null && echo true || echo false)"
    postgressql_installed_flag="$(kubectl get ns my-postgresql &> /dev/null && echo true || echo false)"
    mysql_installed_flag="$(kubectl get ns my-mysql &> /dev/null && echo true || echo false)"
}

setsc(){
    echo '-------Set the default sc & vsc'
    oc annotate volumesnapshotclass csi-aws-vsc k10.kasten.io/is-snapshot-class=true
    oc annotate sc gp2 storageclass.kubernetes.io/is-default-class-
    oc annotate sc gp2-csi storageclass.kubernetes.io/is-default-class=true
}

installk10(){
    echo '-------Install K10'
    kubectl create ns kasten-io
    helm install k10 kasten/k10 --namespace=kasten-io \
        --set scc.create=true \
        --set route.enabled=true \
        --set auth.tokenAuth.enabled=true \
        --set grafana.enabled=true \
        --set global.persistence.storageClass=gp2-csi

    echo '-------Set the default ns to k10'
    kubectl config set-context --current --namespace kasten-io
}

installpgsql(){
    echo '-------Deploying a PostgreSQL database'
    kubectl create namespace my-postgresql
    oc adm policy add-scc-to-user anyuid -z default -n my-postgresql
    helm install --namespace my-postgresql postgres bitnami/postgresql \
    --set primary.persistence.size=1Gi
}

installmysql(){
    echo '-------Deploying a MySQL database'
    kubectl create namespace my-mysql
    oc adm policy add-scc-to-user anyuid -z mysql-release -n my-mysql
    helm install --namespace my-mysql mysql-release bitnami/mysql \
    --set primary.persistence.size=1Gi
}

get_k10_installed_detail(){
    echo '-------Output the Cluster ID'
    clusterid=$(kubectl get namespace default -ojsonpath="{.metadata.uid}{'\n'}")
    echo "" | awk '{print $1}' > ocp_aws_token
    echo My Cluster ID is $clusterid >> ocp_aws_token

    echo '-------Wait for 1 or 2 mins for the Web UI IP and token'
    kubectl wait --for=condition=ready --timeout=180s -n kasten-io pod -l component=jobs
    k10ui=http://$(kubectl get route -n kasten-io | grep k10-route | awk '{print $2}')/k10/#
    echo -e "\nCopy/Paste the link to browser to access K10 Web UI" >> ocp_aws_token
    echo -e "\n$k10ui" >> ocp_aws_token
    echo "" | awk '{print $1}' >> ocp_aws_token
    sa_secret=$(kubectl get serviceaccount k10-k10 -o json -n kasten-io | grep k10-k10-token | awk '{print $2}' | sed -e 's/\"//g')
    # sa_secret=$(kubectl get serviceaccount k10-k10 -o jsonpath="{.secrets[0].name}{'\n'}" --namespace kasten-io)

    echo "Copy/Paste the token below to Signin K10 Web UI" >> ocp_aws_token
    echo "" | awk '{print $1}' >> ocp_aws_token
    kubectl get secret $sa_secret --namespace kasten-io -ojsonpath="{.data.token}{'\n'}" | base64 --decode | awk '{print $1}' >> ocp_aws_token
    # kubectl get secret $sa_secret -n kasten-io -o json | jq '.metadata.annotations."openshift.io/token-secret.value"' | sed -e 's/\"//g' >> ocp_aws_token
    echo "" | awk '{print $1}' >> ocp_aws_token

    echo '-------Waiting for K10 services are up running in about 1 or 2 mins'
    kubectl wait --for=condition=ready --timeout=300s -n kasten-io pod -l component=catalog

    echo '-------Accessing K10 UI'
    cat ocp_aws_token

    endtime=$(date +%s)
    duration=$(( $endtime - $starttime ))
    echo "-------Total time for K10 deployment is $(($duration / 60)) minutes $(($duration % 60)) seconds."
    echo "" | awk '{print $1}'
}

destroy(){
    starttime=$(date +%s)
    if [ "${k10_installed_flag}" == "true" ]; then
        helm uninstall k10 -n kasten-io
        kubectl delete ns kasten-io
    fi
    if [ "${postgressql_installed_flag}" == "true" ]; then
        helm uninstall postgres -n my-postgresql
        kubectl delete ns my-postgresql
    fi
    if [ "${mysql_installed_flag}" == "true" ]; then
        helm uninstall mysql-release -n my-mysql
        kubectl delete ns my-mysql
    fi
    remove_bucket
    echo "" | awk '{print $1}'
    endtime=$(date +%s)
    duration=$(( $endtime - $starttime ))
    echo "-------Total time is $(($duration / 60)) minutes $(($duration % 60)) seconds."
    echo "" | awk '{print $1}'
}

remove_bucket(){
    REMOVE_BUCKET="$(yq '.spec.locationSpec.objectStore.name' ocp-s3-location.yaml)"
    export AWS_ACCESS_KEY_ID=$(cat awsaccess | head -1)
    export AWS_SECRET_ACCESS_KEY=$(cat awsaccess | tail -1)
    mc alias set ${OCP_AWS_MY_OBJECT_STORAGE_PROFILE} https://${OCP_AWS_ENDPOINT} ${AWS_ACCESS_KEY_ID} ${AWS_SECRET_ACCESS_KEY} --api S3v4
    mc ls ${OCP_AWS_MY_OBJECT_STORAGE_PROFILE}/${REMOVE_BUCKET} >/dev/null 2>&1
    if [ ${?} -eq 0 ]; then
        mc rb ${OCP_AWS_MY_OBJECT_STORAGE_PROFILE}/${REMOVE_BUCKET} --force
    fi
}

check_helm(){
    has_helm="$(which helm &> /dev/null && echo true || echo false)"
    if [ ${has_helm} = "false" ]; then
        wget https://get.helm.sh/helm-v3.7.1-linux-amd64.tar.gz
        tar zxf helm-v3.7.1-linux-amd64.tar.gz
        mkdir ~/bin
        mv linux-amd64/helm ~/bin
        rm helm-v3.7.1-linux-amd64.tar.gz 
        rm -rf linux-amd64 
        export PATH=$PATH:~/bin
    else
        echo "Helm is already installed."
    fi
    helm repo add kasten https://charts.kasten.io
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
}

check_yq(){
    has_yq="$(which yq &> /dev/null && echo true || echo false)"
    if [ ${has_yq} = "false" ]; then
        wget https://github.com/mikefarah/yq/releases/download/v4.27.2/yq_linux_amd64 -O ~/bin/yq 
        chmod +x ~/bin/yq
    else
        echo "yq is already installed."
    fi
}

check_mc(){
    has_mc="$(which mc &> /dev/null && echo true || echo false)"
    if [ ${has_mc} = "false" ]; then
        wget https://dl.min.io/client/mc/release/linux-amd64/mc -O ~/bin/mc
        chmod +x ~/bin/mc
    else
        echo "mc is already installed."
    fi
}

create_location_profile(){
    read -p "Enter your AWS Access Key ID and press [ENTER]: " AWS_ACCESS_KEY_ID
    echo "" | awk '{print $1}'
    echo $AWS_ACCESS_KEY_ID > awsaccess
    read -p "Enter your AWS Secret Access Key and press [ENTER]: " AWS_SECRET_ACCESS_KEY
    echo $AWS_SECRET_ACCESS_KEY >> awsaccess
    export AWS_ACCESS_KEY_ID=$(cat awsaccess | head -1)
    export AWS_SECRET_ACCESS_KEY=$(cat awsaccess | tail -1)

    echo '-------Creating a S3 profile secret'
    kubectl create secret generic k10-s3-secret \
      --namespace kasten-io \
      --type secrets.kanister.io/aws \
      --from-literal=aws_access_key_id=$(cat awsaccess | head -1) \
      --from-literal=aws_secret_access_key=$(cat awsaccess | tail -1)

    update_yaml
    kubectl apply -f ocp-s3-location.yaml
}

update_yaml(){
    YML_REGION=${OCP_AWS_MY_REGION} YML_BUCKET=${OCP_AWS_MY_BUCKET} YML_PROFILE=${OCP_AWS_MY_OBJECT_STORAGE_PROFILE} YML_ENDPOINT=${OCP_AWS_ENDPOINT} yq -i '.metadata.name = strenv(YML_PROFILE) | 
    .spec.locationSpec.objectStore.endpoint = strenv(YML_ENDPOINT) | 
    .spec.locationSpec.objectStore.name = strenv(YML_BUCKET) | 
    .spec.locationSpec.objectStore.region = strenv(YML_REGION)
    ' ocp-s3-location.yaml
}

main_installer(){
    if [ "${Install_Select}" == "1" ] || [ "${Install_Select}" == "2" ] || [ "${Install_Select}" == "3" ] || [ "${Install_Select}" == "4" ] || [ "${Install_Select}" == "5" ] || [ "${Install_Select}" == "6" ]; then
        if [ "${k10_installed_flag}" == "false" ]; then
            installk10
        fi
    fi
    if [ "${Install_Select}" == "2" ] || [ "${Install_Select}" == "5" ]; then
        if [ "${postgressql_installed_flag}" == "false" ]; then
            installpgsql
        fi
    fi
    if [ "${Install_Select}" == "3" ] || [ "${Install_Select}" == "6" ]; then
        if [ "${mysql_installed_flag}" == "false" ]; then
            installmysql
        fi
    fi
    if [ "${Install_Select}" == "1" ] || [ "${Install_Select}" == "2" ] || [ "${Install_Select}" == "3" ] || [ "${Install_Select}" == "4" ] || [ "${Install_Select}" == "5" ] || [ "${Install_Select}" == "6" ]; then
        get_k10_installed_detail
    fi
    if [ "${Install_Select}" == "4" ] || [ "${Install_Select}" == "5" ] || [ "${Install_Select}" == "6" ]; then
        create_location_profile
    fi
    if [ "${Install_Select}" == "7" ]; then
        destroy
    fi
}

OCP_AWS_MY_OBJECT_STORAGE_PROFILE="wasabi"
ran_str=`randstr`
OCP_AWS_MY_BUCKET="k10-openshift-lei-${ran_str}"
OCP_AWS_MY_REGION="ap-southeast-1"
OCP_AWS_ENDPOINT="s3.ap-southeast-1.wasabisys.com"

#prepare env
if [ -e ~/ran ]; then
    echo ""
else
    setsc
    check_helm
    check_yq
    check_mc
    touch ~/ran
fi

starttime=$(date +%s)
clearscreen
Display_Selection
Press_Install
check_k10_installed
main_installer
