import getUuid from './uuid';

let sessionId = getUuid();

export const getGreetingSessionId = () => {
  if (window.chatwootWebChannel?.greetingMode === 'every_open_first_message') {
    return sessionId;
  }
  return null;
};

export const startGreetingSession = () => {
  sessionId = getUuid();
  return sessionId;
};
