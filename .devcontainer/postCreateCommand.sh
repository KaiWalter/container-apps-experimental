az bicep install

az extension add --source https://workerappscliextension.blob.core.windows.net/azure-cli-extension/containerapp-0.2.4-py2.py3-none-any.whl -y

az extension add -n application-insights

bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
