let systemInfo = {};

chrome.management.getSelf(function(info) {
    systemInfo.isManaged = info.isManaged;
});

chrome.system.cpu.getInfo(function(info) {
    systemInfo.cpu = info;
});

chrome.system.memory.getInfo(function(info) {
    systemInfo.memory = info;
});

chrome.system.storage.getInfo(function(info) {
    systemInfo.storage = info;
});

// Listen for a message from the popup to send the data
chrome.runtime.onMessage.addListener(function(request, sender, sendResponse) {
    if (request.action == "getSystemInfo") {
        sendResponse(systemInfo);
    }
});