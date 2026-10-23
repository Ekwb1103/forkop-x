import { ValidationResult } from './types';
import { isValidPort, parseHostPort } from './hostPort';

export function validateTrojanUrl(url: string): ValidationResult {
  try {
    if (!url.startsWith('trojan://')) {
      return {
        valid: false,
        message: _('Invalid Trojan URL: must start with trojan://'),
      };
    }

    // The fragment is a display name, not part of the connection address.
    // Permit spaces there while still rejecting whitespace in credentials,
    // host and transport parameters, and control characters anywhere.
    if (/\s/.test(url.split('#', 1)[0]) || /\p{Cc}/u.test(url)) {
      return {
        valid: false,
        message: _('Invalid Trojan URL: must not contain spaces'),
      };
    }

    const body = url.slice('trojan://'.length);
    const [mainPart] = body.split('#');
    const [userHostPort] = mainPart.split('?');

    const [userPart, hostPortPart] = userHostPort.split('@');

    if (!userHostPort)
      return {
        valid: false,
        message: 'Invalid Trojan URL: missing credentials and host',
      };

    if (!userPart)
      return { valid: false, message: 'Invalid Trojan URL: missing password' };

    if (!hostPortPart)
      return {
        valid: false,
        message: 'Invalid Trojan URL: missing hostname and port',
      };

    const parsedHostPort = parseHostPort(hostPortPart);
    if (!parsedHostPort)
      return {
        valid: false,
        message: 'Invalid Trojan URL: invalid host and port',
      };
    const { host, port } = parsedHostPort;

    if (!host)
      return { valid: false, message: 'Invalid Trojan URL: missing hostname' };

    if (!port)
      return { valid: false, message: 'Invalid Trojan URL: missing port' };

    if (!isValidPort(port))
      return {
        valid: false,
        message: 'Invalid Trojan URL: invalid port number',
      };
  } catch (_e) {
    return { valid: false, message: _('Invalid Trojan URL: parsing failed') };
  }

  return { valid: true, message: _('Valid') };
}
