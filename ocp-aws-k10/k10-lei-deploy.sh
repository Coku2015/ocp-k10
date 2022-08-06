#! /bin/bash
contact_us=lei.wei@veeam.com

fun_set_text_color(){
    COLOR_RED='\E[1;31m'
    COLOR_GREEN='\E[1;32m'
    COLOR_YELOW='\E[1;33m'
    COLOR_BLUE='\E[1;34m'
    COLOR_PINK='\E[1;35m'
    COLOR_PINKBACK_WHITEFONT='\033[45;37m'
    COLOR_GREEN_LIGHTNING='\033[32m \033[05m'
    COLOR_END='\E[0m'
}

Press_Install(){
    echo ""
    echo -e "${COLOR_GREEN}Press any key to install...or Press Ctrl+c to cancel${COLOR_END}"
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
    echo "| A tool to help you create automate k10 installation in 3 minutes|"
    echo "+-----------------------------------------------------------------+"
    echo "|  Intro: ${contact_us}                           |"
    echo "+-----------------------------------------------------------------+"
    echo ""
}

Display_Selection(){
    def_Install_Select="1"
    echo -e "${COLOR_YELOW}You have 6 options for your K10 installation.${COLOR_END}"
    echo "1: Install K10 only"
    echo "2: Install K10 and PostgreSQL"
    echo "3: Install K10 and MySQL"
    echo "4: Install K10 and configure object storage"
    echo "5: Install K10/PostgreSQL/Object Storage"
    echo "6: Install K10/MySQL/Object Storage"
    echo "7: Uninstall everything."
    read -p "Enter your choice (1-6 or exit. default [${def_Install_Select}]): " Install_Select

    case "${Install_Select}" in
    1)
        echo
        echo -e "${COLOR_GREEN}You will install K10.${COLOR_END}"
        ;;
    2)
        echo
        echo -e "${COLOR_GREEN}You will install K10 and PostgreSQL.${COLOR_END}"
        ;;
    3)
        echo
        echo -e "${COLOR_GREEN}You will install K10 and MySQL.${COLOR_END}"
        ;;
    4)
        echo
        echo -e "${COLOR_GREEN}You will install K10 and configure object storage.${COLOR_END}"
        ;;
    5)
        echo
        echo -e "${COLOR_GREEN}You will install K10/PostgreSQL/Object Storage.${COLOR_END}"
        ;;
    6)
        echo
        echo -e "${COLOR_GREEN}You will install K10/MySQL/Object Storage.${COLOR_END}"
        ;;
    [eE][xX][iI][tT])
        echo -e "${COLOR_GREEN}You select <Exit>, shell exit now!${COLOR_END}"
        exit 1
        ;;
    *)
        echo
        echo -e "${COLOR_GREEN}No input,You will install k10 only.${COLOR_END}"
        Install_Select="${def_Install_Select}"
    esac
}

check_k10_installed(){
    k10_installed_flag=""
    postgressql_installed_flag=""
    mysql_installed_flag=""
    check_k10=$(kubectl get ns kasten-io | grep kasten-io | awk '{print $1}')
    check_pgsql=$(kubectl get ns my-postgresql | grep my-postgresql | awk '{print $1}')
    check_mysql=$(kubectl get ns my-mysql | grep my-mysql | awk '{print $1}')
    if [[ "${check_k10}" == "kasten-io" ]]; then
        k10_installed_flag="true"
    else
        k10_installed_flag="false"
    fi
    if [[ "${check_pgsql}" == "my-postgresql" ]]; then
        postgressql_installed_flag="true"
    else
        postgressql_installed_flag="false"
    fi
    if [[ "${check_mysql}" == "my-mysql" ]]; then
        mysql_installed_flag="true"
    else
        mysql_installed_flag="false"
    fi
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
    #For Production, remove the lines ending with =1Gi from helm install
    #For Production, remove the lines ending with airgap from helm install
    helm install k10 kasten/k10 --namespace=kasten-io \
        --set global.persistence.metering.size=1Gi \
        --set prometheus.server.persistentVolume.size=1Gi \
        --set global.persistence.catalog.size=1Gi \
        --set global.persistence.jobs.size=1Gi \
        --set global.persistence.logging.size=1Gi \
        --set global.persistence.grafana.size=1Gi \
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
    oc adm policy add-scc-to-user anyuid -z default -n my-mysql
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
        helm uninstall postgres -n my-mysql
        kubectl delete ns my-mysql
    fi
    echo "" | awk '{print $1}'
    endtime=$(date +%s)
    duration=$(( $endtime - $starttime ))
    echo "-------Total time is $(($duration / 60)) minutes $(($duration % 60)) seconds."
    echo "" | awk '{print $1}'
}

check_helm(){
    which helm
    if [ `echo $?` -eq 1 ]; then
        wget https://get.helm.sh/helm-v3.7.1-linux-amd64.tar.gz
        tar zxf helm-v3.7.1-linux-amd64.tar.gz
        mkdir ~/bin
        mv linux-amd64/helm ~/bin
        rm helm-v3.7.1-linux-amd64.tar.gz 
        rm -rf linux-amd64 
        export PATH=$PATH:~/bin
    fi
    helm repo add kasten https://charts.kasten.io
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
}

main_installer(){
    if [ "${k10_installed_flag}" == "false" ] || [ "${Install_Select}" == "1" ] || [ "${Install_Select}" == "2" ] || [ "${Install_Select}" == "3" ] || [ "${Install_Select}" == "4" ] || [ "${Install_Select}" == "5" ] || [ "${Install_Select}" == "6" ]; then
        installk10
    fi
    if [ "${postgressql_installed_flag}" == "false" ] || [ "${Install_Select}" == "2" ] || [ "${Install_Select}" == "5" ]; then
        installpgsql
    fi
    if [ "${mysql_installed_flag}" == "false" ] || [ "${Install_Select}" == "3" ] || [ "${Install_Select}" == "6" ]; then
        installmysql
    fi
    if [ "${Install_Select}" == "1" ] || [ "${Install_Select}" == "2" ] || [ "${Install_Select}" == "3" ] || [ "${Install_Select}" == "4" ] || [ "${Install_Select}" == "5" ] || [ "${Install_Select}" == "6" ]; then
        get_k10_installed_detail
    fi
    if [ "${Install_Select}" == "7" ]; then
        destroy
    fi
}

starttime=$(date +%s)

setsc
clearscreen
Display_Selection
Press_Install
check_helm
check_k10_installed
main_installer
