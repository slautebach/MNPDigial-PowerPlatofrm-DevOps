# DevOps-Pipelines

All DevOps YAML pipelines are stored here to be used

## DevOps-Pipeline-Build.yml

The build pipeline that will compile all package components.  Packages them and publishes them as an artifact to be used by any release pipeline

## DevOps-Pipeline-BuildPullRequest.yml

The build pipeline to verify everthing can build successfully before allowing a pull request to be completed.

## DevOps-Pipeline-Export-All-PullRequest.yml


## DevOps-Pipeline-Export-Data-PullRequest
Pipeline to extract configuration data from the $(TargetEnvironment), and creates a pull request

Required Variables:
TargetEnvironment - The org name part of the org url
AppId - The application guid of the application user
ClientSecret - The client secret of the application 

##DevOps-Pipeline-Export-Portal-PullRequest

##DevOps-Pipeline-Export-PullRequest

##DevOps-Pipeline-Export-Solution-PullRequest

##DevOps-Pipeline-Template-Build