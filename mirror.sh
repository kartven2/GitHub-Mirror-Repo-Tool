#!/bin/bash
#######################################################################
#Copyright [2020] Karthik.V
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at

#    http://www.apache.org/licenses/LICENSE-2.0

#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.
#########################################################################
# Author: Karthik.V (kafy83@gmail.com)
#
# Name: Mirroring a GitHub repository
# Purpose: Mirror a repository in another project, including getting updates
# from the original. This script creates a new repository in destination
# project if it doesn't exists. Also can be run periodically to fetch from the
# original repository and push the changes to the mirrored repository.
#
# A mirrored clone repository includes all remote branches and tags, but all
# local references will be overwritten each time you fetch, so it will always
# be the same as the original repository.
#
# Input:
#
# 1) Absolute path to ${source_info_file} containing URL of the source
#    repository in the following format.
#
#    url: "git@github.com:kartven2/Puzzle.git"
#
#   For ex: Path to file such as gogradle.lock
#
# 2) ${credentials} of user with read and write access of both source and
#    destination repository. User MUST also add his/her SSH Keys into
#    both the source and destination GitHub accounts.
#
# 3) ${dest_project} Destination GitHub project.
#    For ex: git@github.com:destination
#
# Output:
#
# 1) All the repositories specified in the ${source_info_file} will be mirrored
#    into ${dest_project}.
#
# 2) A new ${_new_info_file} file containing update URL pointing to repository
#    in ${dest_project}.
#
# Assumptions:
#
# - GitHub User account on both source and destination project MUST have SSH
#   public keys from where this script is run.
# - SSH agent must be running on the system and must have the right SSH keys.
# - User MUST have both read and write permissions to both source and destination
#   GitHub projects.
# - All the source repositories specified in ${source_info_file} are SSH URL and
#   NOT HTTPS URL
# - git, curl is available on the system where this script will be run.
# - Enough space is availble on the disk to clone each source repository.
#

CURL_OUTPUT_LOG="curl_out.log"
trap "exit 1" TERM
export TOP_PID=$$

function log_and_exit() {
  case "${1}" in
  1)
    echo "Source repository project info file not found"
    kill -s TERM "${TOP_PID}"
    ;;
  2)
    echo "Repository ${2} creation failed. Reason in ${CURL_OUTPUT_LOG}"
    kill -s TERM "${TOP_PID}"
    ;;
  *)
    echo "Unknown error"
    kill -s TERM "${TOP_PID}"
    ;;
  esac
}

function get_dest_project() {
  local _default_dest_project="git@github.com:xyz/example.git"
  local _dest_project="${_default_dest_project}"
  read -p "Enter destination github project [${_default_dest_project}]:" _dest_project
  _dest_project=${_dest_project:-${_default_dest_project}}
  echo "${_dest_project}"
}

function get_source_project_info_file() {
  local _default_source_info_file="gogradle.lock"
  local _source_info_file="${_default_source_info_file}"
  read -p "Enter source repository project info file [${_default_source_info_file}]:" _source_info_file
  _source_info_file=${_source_info_file:-${_default_source_info_file}}
  if [ -e "${_source_info_file}" ]; then
    echo "${_source_info_file}"
  fi
}

function get_credentials() {
  local _default_username="user@github.com"
  local _username="${_default_username}"
  read -p "Username [${_default_username}]:" _username
  _username=${_username:-${_default_username}}
  read -s -p "Password:" _password
  local _credentials="${_username}:${_password}"
  echo "${_credentials}"
}

function parse_file() {
  local _file="${1}"
  local _source_info_file_urls=$(grep 'url:' "${_file}" | sed -n -e 's/^.*url: //p' | sed -e 's/^"//' -e 's/"$//')
  echo "${_source_info_file_urls}"
}

function create_repo() {
  local _payload="${1}"
  local _credentials="${2}"
  curl -u ${_credentials} -d ${_payload} https://api.github.com/user/repos >"${CURL_OUTPUT_LOG}" 2>&1
  grep -q 'created_at' "${CURL_OUTPUT_LOG}"
  local _repo_creation_status=$?
  echo "${_repo_creation_status}"
}

function check_repo() {
  local _repo_name="${1}"
  local _repo_url="${2}"
  git ls-remote "${_repo_url}" >/dev/null 2>&1
  local _repo_exists=$?
  echo "${_repo_exists}"
}

function clone_repo() {
  local _repo_url="${1}"
  git clone --mirror "${_repo_url}"
}

function line_break() {
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

function mirror_repo_make_new_source_file() {
  local _credentials="${1}"
  local _source_info_file="${2}"
  local _dest_repo="${3}"
  local _new_info_file="${_source_info_file}_new"

  echo "Copy and create new info file"
  cp "${_source_info_file}" "${_new_info_file}"

  echo "Preparing to mirror repositories specified in ${_source_info_file} into ${_dest_repo}"
  local _source_repo_list=($(parse_file "${_source_info_file}"))
  echo "Found ${#_source_repo_list[@]} url entries in ${_source_info_file}"

  for _index in "${!_source_repo_list[@]}"; do
    line_break
    _source_repo_url=${_source_repo_list[_index]}
    _source_repo_name=${_source_repo_url##*/}
    _source_proj=$(dirname ${_source_repo_url})

    echo "Processing $((_index + 1)) repo-name: ${_source_repo_name}, source-repo: ${_source_repo_url}"
    _dest_repo_url="${_dest_repo}/${_source_repo_name}"

    echo "- Checking if destination-repo: ${_dest_repo_url} exists"
    _dest_repo_exists=$(check_repo "${_source_repo_name}" "${_dest_repo_url}")
    if [ "${_dest_repo_exists}" -eq 0 ]; then
      echo "- Found repository ${_dest_repo_url}"
    else
      echo "- Repository ${_dest_repo_url} not found"
      local _repo_creation_data='{"name":"%s"}\n'
      local _payload=$(printf "${_repo_creation_data}" "${_source_repo_name}")
      _dest_repo_creation=$(create_repo "${_payload}" "${_credentials}")
      if [ "${_dest_repo_creation}" -eq 0 ]; then
        rm -rf "${CURL_OUTPUT_LOG}"
        echo "- Created new repository ${_dest_repo_url}"
      else
        log_and_exit 2 "${_dest_repo_url}"
      fi
    fi

    echo "- Cloning source-repo: ${_source_repo_url}"
    clone_repo "${_source_repo_url}"
    cd "${_source_repo_name}"

    echo "- Set remote push URL: ${_dest_repo_url}"
    git remote set-url --push origin "${_dest_repo_url}"

    echo "- Sync repository"
    git fetch -p origin
    git push --mirror

    echo "- Clean up local repo: ${_source_repo_name}"
    cd ..
    rm -rf "${_source_repo_name}"

    echo "Update URL entries in ${_new_info_file} with ${_dest_repo}"
    update_source_project_info_file "${_source_proj}" "${_dest_repo}" "${_new_info_file}"

    echo "Done"
  done
  line_break
}

function update_source_project_info_file() {
  local _source_proj="${1}"
  local _dest_proj="${2}"
  local _info_file="${3}"
  sed -i -e "s+$_source_proj+$_dest_proj+g" "${_info_file}"
  rm -rf "${_new_info_file}-e"
}

function main() {
  credentials=$(get_credentials)
  echo -e "\n All access to GitHub repositories will use SSH keys.\n Credentials will be used only for creation of new repositories."
  printf '%64s\n' | tr ' ' -
  source_info_file=$(get_source_project_info_file)
  if [ -z "${source_info_file}" ]; then
    log_and_exit 1
  fi
  dest_project=$(get_dest_project)
  mirror_repo_make_new_source_file "${credentials}" "${source_info_file}" "${dest_project}"
}

main
