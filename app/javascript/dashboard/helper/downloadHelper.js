import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';

export const downloadCsvFile = (fileName, content) => {
  const contentType = 'data:text/csv;charset=utf-8;';
  const blob = new Blob([content], { type: contentType });
  const url = URL.createObjectURL(blob);

  const link = document.createElement('a');
  link.setAttribute('download', fileName);
  link.setAttribute('href', url);
  link.click();
  return link;
};

const buildDownloadLink = (fileName, blob) => {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('download', fileName);
  link.setAttribute('href', url);
  link.click();
  URL.revokeObjectURL(url);
  return link;
};

const extractFileNameFromDisposition = disposition => {
  if (!disposition) {
    return '';
  }

  const utf8FileNameMatch = disposition.match(/filename\\*=UTF-8''([^;]+)/i);
  if (utf8FileNameMatch?.[1]) {
    return decodeURIComponent(utf8FileNameMatch[1]);
  }

  const fileNameMatch = disposition.match(/filename="?([^";]+)"?/i);
  return fileNameMatch?.[1] || '';
};

export const downloadBlobResponse = (
  response,
  fallbackFileName = 'download.html'
) => {
  const fileName =
    extractFileNameFromDisposition(response.headers['content-disposition']) ||
    fallbackFileName;
  const contentType =
    response.headers['content-type'] || 'application/octet-stream';
  const blob =
    response.data instanceof Blob
      ? response.data
      : new Blob([response.data], { type: contentType });

  return buildDownloadLink(fileName, blob);
};

export const generateFileName = ({ type, to, businessHours = false }) => {
  let name = `${type}-report-${format(fromUnixTime(to), 'dd-MM-yyyy')}`;
  if (businessHours) {
    name = `${name}-business-hours`;
  }
  return `${name}.csv`;
};
