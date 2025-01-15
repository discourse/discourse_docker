
IAM_DATA=$(cat <<EOF
{
    "auth": {
        "identity": {
            "methods": [
                "password"
            ],
            "password": {
                "user": {
                    "domain": {
                        "name": "freesky-edward"
                    },
                    "name": "codearts_test",
                    "password": "$3"
                }
            }
        },
        "scope": {
            "project": {
                "name": "cn-north-4"
            }
        }
    }
}
EOF
)

response=$(curl -s -i --location 'https://iam.myhuaweicloud.com/v3/auth/tokens?nocatalog=true' \
  --header 'Content-Type: application/json' \
  --data "$IAM_DATA")

# Extract the X-Subject-Token from the response
token=$(echo "$response" | grep "X-Subject-Token" | awk '{print $2}' | tr -d '\r')

echo "X-Subject-Token: $token"


DATA=$(cat <<EOF
{
  "sources" : [ {
    "type" : "code",
    "params" : {
      "git_type" : "github",
      "default_branch" : "main",
      "git_url" : "$6",
      "endpoint_id" : "$5",
      "build_params" : {
        "build_type" : "branch",
        "event_type" : "Manual",
        "target_branch" : "$1"
      }
    }
  } ],
  "description" : "运行描述",
  "variables" : [ {
    "name" : "repo",
    "value" : "$8"
  } ,
  {
    "name" : "owner",
    "value" : "$7"
  }
  ,
  {
    "name" : "pr_id",
    "value" : "$2"
  }
  ]
}
EOF
)

CODEARTS_PIPELINE="$4"

curl --location "$CODEARTS_PIPELINE" \
--header "X-Auth-Token:$token" \
--header "Content-Type: application/json" \
--data "$DATA"