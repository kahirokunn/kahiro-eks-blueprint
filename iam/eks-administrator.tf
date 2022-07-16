data "aws_iam_policy_document" "caller-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }
  }
}

resource "aws_iam_role" "eks-administrator" {
  name               = "eks-administrator"
  assume_role_policy = data.aws_iam_policy_document.caller-assume-role-policy.json
}

resource "aws_iam_role_policy_attachment" "eks-administrator-policy-attach" {
  for_each = toset([
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/PowerUserAccess",
  ])
  role       = aws_iam_role.eks-administrator.name
  policy_arn = each.key
}
