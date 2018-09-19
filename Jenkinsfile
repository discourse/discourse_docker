pipeline {
  agent { label 'jenkinsAgent' }
  options{
    buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
  }
  environment {
    GHTOKEN = credentials('gh-atombot')
  }
  stages {
    stage('setup build') {
      steps {
        script {
          gitCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
          repo = "526930246559.dkr.ecr.us-east-1.amazonaws.com"
          appname = 'atom.discourse'
          reponame = 'atom-discourse'
        }
        sh """
          curl -XPOST -H "Authorization: token ${env.GHTOKEN}" ${GHSTATUSURL}${gitCommit} -d "{
            \\"context\\": \\"check-continuous-integration\\",
            \\"state\\": \\"pending\\",
            \\"target_url\\": \\"${env.BUILD_URL}\\",
            \\"description\\": \\"The build is pending\\"
          }"
        """
      }
    }
    stage ('run launcher script') {
      steps {
        sh """
          # run your launcher file
          ./launcher bootstrap app
        """
      }
    }
    stage ('build and push images') {
      steps {
        sh """
          eval \$(aws ecr get-login --region us-east-1)

          docker tag local_discourse/app:latest $appname:master
          docker push ${repo}'/'${appname}:master
        """
      }
    }
  }
  post {
    always {
    }
    success {
      sh """
        curl -XPOST -H "Authorization: token ${env.GHTOKEN}" ${GHSTATUSURL}${gitCommit} -d "{
          \\"context\\": \\"check-continuous-integration\\",
          \\"state\\": \\"success\\",
          \\"target_url\\": \\"${env.BUILD_URL}\\",
          \\"description\\": \\"The build is success\\"
        }"
      """
    }
    unstable {
      sh """
        curl -XPOST -H "Authorization: token ${env.GHTOKEN}" ${GHSTATUSURL}${gitCommit} -d "{
          \\"context\\": \\"check-continuous-integration\\",
          \\"state\\": \\"error\\",
          \\"target_url\\": \\"${env.BUILD_URL}\\",
          \\"description\\": \\"The build is unstable.\\"
        }"
      """
    }
    failure {
      sh """
        curl -XPOST -H "Authorization: token ${env.GHTOKEN}" ${GHSTATUSURL}${gitCommit} -d "{
          \\"context\\": \\"check-continuous-integration\\",
          \\"state\\": \\"failure\\",
          \\"target_url\\": \\"${env.BUILD_URL}\\",
          \\"description\\": \\"The build is failing.\\"
        }"
      """
    }
  }
}
