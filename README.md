
# リソースの作成

```sh
cd terraform
terraform plan
terraform apply
# enter the name of key pair
```
# MySQLテーブルの作成

local
```sh
mysql -uroot -P 3316 -h 127.0.0.1 -p < db/urls.sql
```

cloud
```sh
ssh -i <key-path> ec2-user@<migration_instance_public_ip>
mysql -uroot -P 3306 -h <rds_endpoint> -p

# execute urls.sql
```

# Dockerイメージの更新(latestタグ運用)

```sh
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com
```

```sh
docker build -t api .
docker tag api:latest <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/api:latest
docker push <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/api:latest
```


# ECSサービス更新

タスク定義を更新する

```sh
env ACCOUNT_ID=<account-id> MYSQL_HOST=<MYSQL_HOST> MYSQL_PASSWORD=<MYSQL_PASSWORD>  envsubst < task_definition.json.tpl >task_definition.json
```

```sh
aws ecs register-task-definition --cli-input-json file://task_definition.json
```

ECSサービスを更新する

```sh
aws ecs update-service --cluster test --service url-shorten-api --task-definition arn:aws:ecs:ap-northeast-1:<account-id>:task-definition/api:<version>
```

# HTTPリクエスト

URL短縮
```sh
curl -X POST "http://<alb_endpoint>/api/v1/data/shorten?longURL=https://en.wikipedia.org/wiki/Systems_design"
```

```sh
curl "http://<alb_endpoint>/api/v1/short/<short_url>"
```

# 後片付け

```sh
aws ecs update-service --cluster test --service url-shorten-api --task-definition <task_definition> --desired-count 0
```

```sh
cd terraform
terraform destroy
```
