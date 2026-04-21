export const buildSearchParamsWithLocale = search => {
  // [TODO] for now this works, but we will need to find a way to get the locale from the root component
  const locale = window.WOOT_WIDGET.$root.$i18n.locale;
  const params = new URLSearchParams(search);
  params.append('locale', locale);

  return `?${params}`;
};

export const getLocale = (search = '') => {
  return new URLSearchParams(search).get('locale');
};

export const getReturnUrl = (search = '') => {
  const params = new URLSearchParams(search);
  const configuredReturnUrl =
    params.get('return_url') ||
    params.get('returnUrl') ||
    params.get('back_url') ||
    params.get('backUrl');
  const fallbackReturnUrl = document.referrer;
  const returnUrl = configuredReturnUrl || fallbackReturnUrl;

  if (!returnUrl) {
    return '';
  }

  try {
    const parsedUrl = new URL(returnUrl, window.location.origin);
    const currentUrl = new URL(window.location.href);

    if (!['http:', 'https:'].includes(parsedUrl.protocol)) {
      return '';
    }

    if (
      parsedUrl.origin === currentUrl.origin &&
      parsedUrl.pathname === currentUrl.pathname
    ) {
      return '';
    }

    return parsedUrl.toString();
  } catch {
    return '';
  }
};

export const isStandaloneMode = (search = '') => {
  const params = new URLSearchParams(search);
  const standaloneValue =
    params.get('standalone') || params.get('standaloneMode');

  if (!standaloneValue) {
    return false;
  }

  return !['false', '0'].includes(standaloneValue.toLowerCase());
};

export const getContactDetails = (search = '') => {
  const params = new URLSearchParams(search);
  const name = params.get('name') || params.get('fullName');
  const email = params.get('email');
  const phoneNumber =
    params.get('phone_number') ||
    params.get('phoneNumber') ||
    params.get('phone');

  return {
    ...(name ? { name } : {}),
    ...(email ? { email } : {}),
    ...(phoneNumber ? { phone_number: phoneNumber } : {}),
  };
};

export const buildPopoutURL = ({
  origin,
  conversationCookie,
  websiteToken,
  locale,
  returnUrl,
}) => {
  const popoutUrl = new URL('/widget', origin);
  popoutUrl.searchParams.append('cw_conversation', conversationCookie);
  popoutUrl.searchParams.append('website_token', websiteToken);
  popoutUrl.searchParams.append('locale', locale);
  if (returnUrl) {
    popoutUrl.searchParams.append('return_url', returnUrl);
  }

  return popoutUrl.toString();
};
