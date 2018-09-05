stage('Testing') {
    node('scs_daintvm1') {
        dir('reframe') {
            checkout([$class: 'GitSCM', branches: [[name: 'master']],
                extensions: [[$class: 'WipeWorkspace']], 
                userRemoteConfigs: [[url: 'https://github.com/eth-cscs/reframe.git']]])
        }
        dir('arbor') {
            checkout([$class: 'GitSCM', branches: [[name: 'ci/reframe-tests']],
                extensions: [[$class: 'WipeWorkspace']], 
                userRemoteConfigs: [[url: 'https://github.com/vkarak/arbor.git']]])
            sh("""#!/bin/bash -l
                  git submodule update --init --recursive
                  sbatch --wait -o arbor-ci.out ci/cscs-daint-gpu.sh ../reframe/bin/reframe
                  exit_status=\$?
                  cat arbor-ci.out
                  exit \$exit_status
               """)
        }
        deleteDir()
    }
}
