{
  "Version": "2012-10-17",
  "Statement":
${jsonencode(
    [
for account in accounts: 
      { 
        "Effect": "Allow",
        "Action": ["sts:AssumeRole"]
        "Resource": "arn:aws:iam::${account}:role/${role_name}"
      }
    ]
)}
}

