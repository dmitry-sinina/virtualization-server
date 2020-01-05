let socketWrapper = function({ url, onOpen, onClose, onData, onError }) {
  let socket = new WebSocket(url);
  socket.onopen = function(event) {
    if (onOpen) onOpen(event);
  };
  socket.onclose = function(event) {
    if (onClose) onClose(event);
  };
  socket.onerror = function(error) {
    if (onError) onError(error);
  };
  socket.onmessage = function(event) {
    if (onData) onData(JSON.parse(event.data), event);
  };

  return {
    _socket: socket,
    send: function (data) {
      socket.send(JSON.stringify(data));
    },
    close: function (code, number) {
      socket.close(code, number)
    }
  }
}

let sendXhr = function ({ method, url, payload, headers, onResponse }) {
  let newXHR = new XMLHttpRequest();
  if (onResponse) {
    newXHR.addEventListener('load', function () {
      onResponse(this);
    });
  }
  newXHR.open(method, url);
  if (headers) {
    Object.keys(headers).forEach(function (header) {
      newXHR.setRequestHeader(header, headers[header]);
    });
  }
  //console.log("SEND REQUEST " + method + " " + url + "\n" + payload);
  newXHR.send(payload);
}

const JSON_API_MIME_TYPE = 'application/vnd.api+json';
let sendJsonApi = function({ method, url, payload, onResponse }) {
  sendXhr({
    method: method,
    headers: {
      'Content-Type': JSON_API_MIME_TYPE,
      'Accept': JSON_API_MIME_TYPE
    },
    url: url,
    payload: payload ? " " + JSON.stringify(payload) : undefined,
    onResponse: function ({ response, status }) {
      let resp = JSON.parse(response);
      onResponse({ response: resp, status })
    }
  })
}

window.MainApp = { socket: null, login: null, reloadWebsocket: null };

MainApp.reloadWebsocket = function () {
  if (MainApp.socket) MainApp.socket.close(1000, 'reconnect');

  MainApp.socket = socketWrapper({
    url: "ws://localhost:4567/cable",
    onOpen: function () {
      console.log("WebSocket connected");
      websocketStatusNode.classList.remove('red');
      websocketStatusNode.classList.add('green');
      websocketStatusNode.textContent = 'connected';
    },
    onClose: function(event) {
      console.log("WebSocket connection closed", event.wasClean ? 'clean' : 'dirty', event.code, event.reason);
      websocketStatusNode.textContent = 'not connected';
      websocketStatusNode.classList.remove('green');
      websocketStatusNode.classList.add('red');
    },
    onError: function(error) {
      console.log("WebSocket error " + error.message);
    },
    onData: function (data) {
      console.log("WebSocket data received", data);
    }
  });
};

MainApp.login = function (login, password, successCallback) {
  let payload = {
    data: {
      type: 'sessions',
      attributes: { login, password }
    }
  }
  console.log('login as', login);
  sendJsonApi({
    method: 'POST',
    url: '/api/sessions',
    payload,
    onResponse: function ({ response, status }) {
      console.log('login response', status, response);
      if (status === 201 && successCallback) {
        successCallback();
      }
    }
  });
}

let loginBtn = document.querySelector('.js-login-btn');
let logoutBtn = document.querySelector('.js-logout-btn');
let loginInput = document.querySelector('.js-login-input');
let passwordInput = document.querySelector('.js-password-input');
let tryApiBtn = document.querySelector('.js-try-api-btn');
let screenshotBtn = document.querySelector('.js-screenshot-btn');
let screenshotInput = document.querySelector('.js-screenshot-input');
let websocketBtn = document.querySelector('.js-websocket-btn');
let websocketStatusNode = document.querySelector('.js-websocket-status');

loginBtn.addEventListener('click', function (event) {
  event.preventDefault();
  MainApp.login(loginInput.value, passwordInput.value);
  MainApp.reloadWebsocket();
});

logoutBtn.addEventListener('click', function (event) {
  event.preventDefault();
  let payload = { data: { id: 'sessions', type: 'sessions' } }
  console.log('logout');
  sendJsonApi({
    method: 'DELETE',
    url: '/api/sessions/123',
    payload,
    onResponse: function ({ status, response }) {
      console.log('logout response', status, response);
    }
  });
});

tryApiBtn.addEventListener('click', function (event) {
  event.preventDefault();
  console.log('get virtual machines');
  sendJsonApi({
    method: 'GET',
    url: '/api/virtual-machines',
    onResponse: function ({ status, response }) {
      console.log('virtual-machines response', status, response);
    }
  });
});

screenshotBtn.addEventListener('click', function (event) {
  event.preventDefault();
  let vmId = screenshotInput.value;
  console.log('vm screenshot', vmId);
  MainApp.socket.send({ type: 'screenshot', id: vmId });
});

websocketBtn.addEventListener('click', function (event) {
  event.preventDefault();
  console.log('reload websocket');
  MainApp.reloadWebsocket();
});

// MainApp.login('admin', 'password');
// MainApp.socket.send({ type: 'screenshot', id: 'vm_id });
// MainApp.reloadWebsocket();
