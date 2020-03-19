{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "arn:aws:iam::${trusted_account}:root"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
