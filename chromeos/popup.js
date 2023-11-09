document.getElementById('gatherInfo').addEventListener('click', function() {
    chrome.runtime.sendMessage({action: "getSystemInfo"}, function(response) {
        document.getElementById('output').textContent = JSON.stringify(response, null, 2);
    });
});