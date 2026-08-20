    #!/bin/bash

    sudo yum update -y
    sudo yum install python3 -y
    sudo yum install git -y

    git clone https://github.com/devopswithraj/Devops-Lab


    cd Devops-Lab/aws-two-tier-app-asg-alb-rds/src 

    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt

    export DB_LINK=postgresql://postgres:Admin1234@mydb.ckz202g805d8.us-east-1.rds.amazonaws.com:5432/mydb
    sudo chmod u+x run.sh
    ./run.sh &