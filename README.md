# Script to clear bamboo build artifacts


* Disable the agent, wait for the agent to complete the current job
* Cleanup
* Enable the agent

### Install [Bamboo Agent Read APIs plugin](https://marketplace.atlassian.com/plugins/com.edwardawebb.bamboo-agent-apis) 


 Go to bamboo admin screen => Rest API browser and type agent, uncheck show only public API's


![API Browser](https://github.com/snandam/clear-bamboo-buildartifacts/blob/master/images/api-browser.png)


### Create a new token

![API Browser](https://github.com/snandam/clear-bamboo-buildartifacts/blob/master/images/create-token.png)


```sh
{
    "name": "Test Token",
    "read": true,
    "change": false
}
```

### View available tokens

![API Browser](https://github.com/snandam/clear-bamboo-buildartifacts/blob/master/images/get-token.png)

Store the tokens at the specific location on the bamboo agent. For example : /opt/data/bamboo-agents/token.uuid and update the script with the same

### Update the script as necessary to match your requirements and setup a cron job to perform this operation.

### References
Thanks to [Edward A. Webb](http://www.edwardawebb.com/) for the plugin

* https://marketplace.atlassian.com/plugins/com.edwardawebb.bamboo-agent-apis
* https://eddiewebb.atlassian.net/wiki/display/AAFB/Access+Token+Operations
* https://bitbucket.org/eddiewebb/bamboo-agent-apis