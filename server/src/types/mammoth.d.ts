declare module 'mammoth' {
  export interface MammothResult {
    value: string;
    messages: any[];
  }
  export function extractRawText(input: { buffer: Buffer }): Promise<MammothResult>;
  export function convertToHtml(input: { buffer: Buffer }): Promise<MammothResult>;
}
