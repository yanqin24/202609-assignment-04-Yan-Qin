---
title: "Assignment 4: Introduction to IaC with Packer and Terraform"
---
# Assignment 4: Introduction to IaC with Packer and Terraform

## Objective

This assignment introduces you to Infrastructure as Code using two complementary tools: **Packer** (to build a custom machine image) and **Terraform** (to deploy it). You will build a custom AMI containing a small Flask API, then write Terraform configuration to deploy it as an EC2 instance.

**AI Tools:** You may use AI coding assistants to help draft your Packer/Terraform configuration. Review any AI-generated code carefully before running it — see the "AI Tools for IaC" slides from this module for what to check. You are responsible for understanding and defending every line you submit.

## The Application: Prompt Optimizer API (lite)

Your repository includes `app/server.py` — a small Flask API that cleans, formats, and lightly enhances AI text prompts. This is a deliberately minimal "v0" version; we'll build on it in later assignments. **Do not modify this file.**

It exposes these endpoints:

| Method | Path | Description |
|---|---|---|
| GET | `/` | Lists available routes |
| GET | `/healthcheck` | Returns `{"status": "ok"}` |
| GET | `/version` | Returns app name and version |
| GET | `/stats` | Returns count of processed requests |
| POST | `/clean` | Trims whitespace, collapses spacing |
| POST | `/format` | Capitalizes and punctuates |
| POST | `/enhance` | Expands abbreviations, adds a clarifying suffix |
| POST | `/optimize` | Runs clean → format → enhance as a pipeline |
| POST | `/analyze` | Returns character/word count and estimated token count |

You can try it locally before you build your AMI. This requires you have python3.14 installed on your local machine. :

```bash
# startup the app manually
cd app
pip install -r requirements.txt
PORT=8080 python3 server.py
# start up another terminal and run:
curl http://localhost:8080/healthcheck
curl -X POST http://localhost:8080/optimize -H "Content-Type: application/json" -d '{"prompt": "pls help me asap"}'
```

Port 80 (used once this is deployed) is a privileged port that requires admin/root access, which is why local testing uses `PORT=8080` here instead. On your deployed instance, the systemd service created by `install_app.sh` runs as root and defaults to port 80 automatically — you don't need to set `PORT` there.


## Before You Begin: Configure AWS Credentials Locally

Both Packer and Terraform need to authenticate to your AWS account when you run them from your own laptop. This is separate from the `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets you'll add to GitHub in Part 3 — those only apply to the GitHub Actions workflow. Follow the steps below:

### Step 1: Confirm the AWS CLI is installed

```bash
aws --version
```

You should see output similar to:

```text
aws-cli/2.17.x Python/3.12.x Linux/6.x.x exe/x86_64.ubuntu.24
```

If instead you get `command not found`, install the AWS CLI first by following the official guide: <https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html>.

### Step 2: Configure your credentials

Run:

```bash
aws configure
```

You'll be prompted for four values, one at a time:

```text
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```

Use the same Access Key ID and Secret Access Key you generated in Assignment 1 or you can create new ones. For **Default region name**, you must enter `us-west-2` (this assignment is graded assuming that region). `json` is fine for the output format.

This writes your credentials to `~/.aws/credentials` and `~/.aws/config`. You will not need to enter them again unless they change.

### Step 3: Verify your credentials actually work

```bash
aws sts get-caller-identity
```

A working configuration prints your account ID, user ID, and ARN as JSON:

```json
{
    "UserId": "AIDAEXAMPLE123456789",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

**Check the `Account` field against the AWS account ID you registered in Assignment 1.** If it doesn't match, you've configured credentials for the wrong account — fix this before continuing, since building an AMI or deploying infrastructure in the wrong account will not be graded. You can safety ignore the `UserId` field - this is not the AWS_ACCESS_KEY_ID, it is a hidden field used by AWS.

### Step 4: Verify your default region

```bash
aws configure get region
```

This should print:

```text
us-west-2
```

If it prints something else (or nothing), re-run `aws configure` and re-enter `us-west-2` at the region prompt.

## Part 1: Build Your AMI with Packer
The goal of this task is to create an AWS Machine Image (AMI) with the provided application. This AMI will be  the one deployed by Terraform. 

Your repository includes:

- `app/install_app.sh` — a **complete** installation script that installs Python, copies the app to `/opt/prompt-optimizer`, and registers it as a systemd service (`prompt-optimizer.service`) listening on port 80. You should not need to modify this.
- `packer/ami.pkr.hcl` — a **skeleton** with your requirements written as comments. You will need to create this template file. Follow the details provided in the Module 4 Presentation Slide or use an AI tool to create this. 

### Requirements

Write a Packer template that:

1. Declares the required `amazon` plugin (`source = "github.com/hashicorp/amazon"`, `version >= 1.0.0`).
2. Defines a `source "amazon-ebs" "app"` block that:
   - Builds in `us-west-2`
   - Uses `t2.micro` or `t3.micro` as the build instance type 
   - Uses `ssh_username = "ubuntu"`
   - Looks up the source AMI via `source_ami_filter`: Ubuntu 22.04 LTS amd64, owned by Canonical (owner ID `099720109477`), `most_recent = true`
   - Sets a unique `ami_name` (include `{{timestamp}}`)
3. Defines a `build` block that:
   - References your source
   - Uses a `file` provisioner to copy the `../app` directory to `/tmp/app` on the build instance
   - Uses a `shell` provisioner to run `../app/install_app.sh`

### Build it

Run these commands from inside the `packer/` directory, in order:

```bash
cd packer
packer init .
```

`packer init` reads the `required_plugins` block in your template and downloads the plugins it needs — in this case, the `amazon` plugin that knows how to talk to AWS. You only need to run this once (or again if you change plugin requirements).

```bash
packer validate ami.pkr.hcl
```

`packer validate` checks your template's syntax and catches basic mistakes (typos, missing required arguments, malformed blocks) without actually building anything. This runs in a few seconds — always run it before `packer build` so you're not waiting several minutes just to find a typo.

```bash
packer build ami.pkr.hcl
```

This is the AMI build, and it can take several minutes to complete. Behind the scenes, Packer will:

1. Launch a temporary EC2 instance from the source AMI (the stock Ubuntu 22.04 image).
2. Install required apt packages.
3. Connect to it over SSH automatically — Packer manages its own temporary SSH key pair for this step, so you don't need to supply one.
4. Run your `file` and `shell` provisioners against that instance (copying your app and running `install_app.sh`).
5. Stop the instance and create a new AMI from its disk.
6. Terminate the temporary instance — it no longer exists once the build finishes; only the new AMI remains.

Packer prints progress as it goes. When it finishes successfully, you'll see output like:

```text
==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs.app: AMIs were created:
us-west-2: ami-0abc123def456789
```

**Copy that `ami-...` value** — you'll paste it into `terraform.tfvars` in Part 2.

If the build fails partway through, Packer usually leaves useful error output in the terminal (a failed provisioner command, an AWS permissions error, etc.) — read the last 10-15 lines of output before assuming something is broken in a way that requires help.

## Part 2: Deploy It with Terraform

Your `terraform/` directory contains:

- `versions.tf` — Terraform and AWS provider setup. **Provided complete.**
- `network.tf` — looks up your account's default VPC and default subnets, and defines a security group. **Provided complete.** (Building a custom VPC is covered in Module 5 — this assignment intentionally uses the default VPC to keep the focus on Packer and Terraform.)
- `variables.tf`, `compute.tf`, `outputs.tf` — skeletons with requirements as comments. You will need to configure your own files.

### Requirements

1. **`variables.tf`**: declare `ami_id` (no default — supplied via `terraform.tfvars`), `instance_type` (default `"t2.micro"`), and `key_name` (no default).
2. **`compute.tf`**: define an `aws_instance` resource that:
   - Uses `var.ami_id`, `var.instance_type`, `var.key_name`
   - Attaches `aws_security_group.app_sg.id` (from `network.tf`)
   - Launches into `data.aws_subnets.default.ids[0]` (from `network.tf`)
   - Tags the instance with **exactly**:
     - `Name = "prompt-optimizer-app"`
     - `AssignedBy = "csye6225-assignment4"`

     (The autograder checks these tag values exactly — typos or omissions will cost you points.)
3. **`outputs.tf`**: define an output named **exactly** `instance_public_ip` that exposes the instance's public IP. Gradescope reads this value directly from your committed `terraform.tfstate` — the name must match exactly.

### Configure your variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set ami_id to your Packer build's output, and key_name to your EC2 key pair
```

`terraform.tfvars` is committed to your repo — it contains no secrets (an AMI ID and key pair name aren't sensitive), and GitHub Actions needs it to run `terraform apply` automatically.

### Understanding the Terraform commands

You won't necessarily run all of these yourself locally (GitHub Actions handles the actual deployment — see Part 3), but you should understand what each one does, and running the first two locally is a good way to catch mistakes before pushing:

```bash
terraform init
```

Reads `versions.tf` and downloads the AWS provider plugin it declares. Like `packer init`, this only needs to run once per project (or again if you change provider requirements). This also sets up your local state file (`terraform.tfstate`) if one doesn't exist yet.

```bash
terraform plan
```

Shows you exactly what Terraform *would* change, without changing anything. It compares your `.tf` files against the current state and prints a summary like `Plan: 2 to add, 0 to change, 0 to destroy`. Run this locally after writing your `compute.tf`/`variables.tf`/`outputs.tf` to sanity-check your work before pushing — if `terraform plan` errors out or shows something unexpected, fix it before committing.

```bash
terraform apply
```

Actually creates (or updates) the resources in AWS. Run without any flags, it shows you the same plan output and asks you to type `yes` to confirm — this interactive confirmation is a safety net against accidentally applying the wrong changes. This is the step GitHub Actions runs automatically (with the `-auto-approve` flag, since there's no one there to type `yes`) every time you push.

```bash
terraform destroy
```

Tears down every resource this configuration created. You'll use this at the end, once Gradescope confirms a passing score (see Part 4).

**A note on running `terraform apply` locally:** you're welcome to run it yourself to test things end-to-end before pushing, but remember that whoever applies last "wins" — if you apply locally and then push, GitHub Actions will apply again (usually a no-op if nothing changed) and will be the one to commit the resulting `terraform.tfstate`. Don't be surprised if the state file changes slightly even when your infrastructure didn't.

---

## Part 3: Automate Deployment with GitHub Actions

Your repository includes `.github/workflows/deploy.yml.example` — a reference workflow that runs `terraform apply` on every push, then commits the updated `terraform.tfstate` back to your repository (Gradescope reads your instance's public IP from that committed file).

To activate it:

1. Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as repository secrets (Settings > Secrets and variables > Actions).
2. Rename `deploy.yml.example` to `deploy.yml`.
3. Commit and push. Watch the **Actions** tab — a successful run deploys your instance and commits the updated state file back automatically.

**Important:** the workflow's commit step includes `[skip ci]` in its commit message. GitHub does not re-trigger a workflow for commits containing this marker. Do not remove it — without it, every state-file commit would trigger another deploy, which would commit again, forever.

---

## Part 4: Submission (Gradescope)

Submission works the same way as previous assignments: link your GitHub repository to the Assignment 4 entry in Gradescope. 

The autograder does two things:

1. **Inspects your committed `terraform/terraform.tfstate`** to check your instance type, required tags, and security group rules — proving you made the correct infrastructure decisions, not just that something is running.
2. **Makes live requests** to your deployed instance: `/healthcheck`, `/version`, and a `/optimize` call with a fixed test prompt, checking for an exact expected response. This last check confirms the *actual* Prompt Optimizer app is running — not just any server.

**Keep your instance running until Gradescope confirms a pass.** You may resubmit as many times as needed before the deadline — push again (or trigger the workflow again) and resubmit in Gradescope.

### Clean up

Once Gradescope confirms a passing score, then you will need to tear down your infrastructure.  Because the GitHub actions workflow runs `terraform apply` on GitHub's runner, your local `terraform.tfstate` file is out of sync with the version on your repository.  In order to properly destroy your infrastructure, you will need to sync the tfstate file in your local repository before you can perform a `terraform destroy`.
The commands will perform the file sync and allow you to destroy your infrastructure properly.

```bash
# in your repository root directory
# the pull will update your local repo from GithHub and update the terraform.tfstate file. 
git pull
cd terraform
terraform destroy
```

Terminating promptly avoids unnecessary charges — this is a t2.micro/t3.micro instance, so costs are minimal, but there's no reason to leave it running longer than needed.


## Grading Rubric (20 points total)

| Check | Points |
|---|---|
| Required files present (`ami.pkr.hcl`, `compute.tf`, `variables.tf`, `outputs.tf`, `terraform.tfstate`) | 1 |
| Instance type is `t2.micro` or `t3.micro` | 2 |
| Required tags present with exact values | 2 |
| Security group allows HTTP (80) and SSH (22) | 3 |
| Terraform output `instance_public_ip` present and valid | 1 |
| Live check: `GET /healthcheck` | 3 |
| Live check: `GET /version` | 2 |
| Live check: `POST /optimize` functional test | 6 |

**Deductions:**
- No credit: wrong region (not `us-west-2`), or using a different AWS account than the one registered in Assignment 1.
- No credit: secrets or credentials hardcoded or visible in the repository.
- No credit: `app/server.py` or `app/install_app.sh` modified.


## Common Pitfalls & Hints

- **Packer**: `ami_name` must be unique per build — reusing a name from a previous build will fail. The `{{timestamp}}` function handles this for you.
- **Terraform**: forgetting to add `terraform.tfvars` means `terraform apply` will prompt for `ami_id` and `key_name` interactively — and will fail non-interactively in GitHub Actions.
- **Tags**: the autograder checks for *exact* tag key/value matches. Double-check spelling and capitalization.
- **State file**: don't add `terraform.tfstate` to `.gitignore` — it's deliberately excluded from the ignore rules in your repo template. If Gradescope can't find it, every dependent check fails.
- **Security group**: reference `aws_security_group.app_sg.id` from `network.tf` rather than writing your own — the ports it opens are exactly what the autograder checks for.
- **The `/optimize` functional test**: if this fails but your infrastructure checks pass, your instance is likely up but not running the actual app correctly — check that your Packer provisioners ran successfully and the `prompt-optimizer.service` is active (`sudo systemctl status prompt-optimizer`).

## Academic Integrity

- You must use your own AWS account registered in Assignment 1.
- You may discuss concepts with classmates; you must write your own configuration.
