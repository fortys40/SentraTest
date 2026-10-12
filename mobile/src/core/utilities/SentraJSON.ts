import Big from 'big.js';

// Wire decoding for Supabase rows. Rows arrive as snake_case JSON; models are
// camelCase with Date timestamps and exact decimals. Decoding is strict: a
// missing required column or an unknown enum value throws instead of producing
// a half-valid model.

export type UUID = string;
export type Decimal = Big;

export type JSONValue =
  | null
  | boolean
  | number
  | string
  | JSONValue[]
  | { [key: string]: JSONValue };

export class DecodingError extends Error {
  constructor(path: string, expectation: string) {
    super(`${path || 'value'}: ${expectation}`);
    this.name = 'DecodingError';
  }
}

export interface Codec<T> {
  decode(value: unknown, path?: string): T;
  encode(value: T): unknown;
}

export type CodecType<C> = C extends Codec<infer T> ? T : never;

const timestampPattern =
  /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|[+-]\d{2}(?::?\d{2})?)$/;

/** Parses an ISO 8601 timestamp that carries a timezone; sub-millisecond digits are truncated. */
export function dateFromTimestamp(value: string): Date | null {
  const match = timestampPattern.exec(value);
  if (!match) return null;
  const [, year, month, day, hour, minute, second, fraction = '', zone] = match;
  const milliseconds = Number(fraction.padEnd(3, '0').slice(0, 3));
  let offsetMinutes = 0;
  if (zone !== 'Z') {
    const digits = zone.slice(1).replace(':', '');
    const magnitude = Number(digits.slice(0, 2)) * 60 + Number(digits.slice(2, 4) || '0');
    offsetMinutes = zone[0] === '-' ? -magnitude : magnitude;
  }
  const instant =
    Date.UTC(+year, +month - 1, +day, +hour, +minute, +second, milliseconds) - offsetMinutes * 60_000;
  return Number.isFinite(instant) ? new Date(instant) : null;
}

export function timestampFromDate(date: Date): string {
  return date.toISOString();
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const string: Codec<string> = {
  decode(value, path = '') {
    if (typeof value !== 'string') throw new DecodingError(path, 'expected a string');
    return value;
  },
  encode: (value) => value,
};

export const boolean: Codec<boolean> = {
  decode(value, path = '') {
    if (typeof value !== 'boolean') throw new DecodingError(path, 'expected a boolean');
    return value;
  },
  encode: (value) => value,
};

export const uuid: Codec<UUID> = {
  decode(value, path = '') {
    if (typeof value !== 'string' || !uuidPattern.test(value)) {
      throw new DecodingError(path, 'expected a UUID');
    }
    return value.toLowerCase();
  },
  encode: (value) => value,
};

/**
 * PostgreSQL integer and bigint columns. JSON numbers above 2^53 cannot be
 * represented exactly in JavaScript, so they are rejected rather than rounded.
 */
export const integer: Codec<number> = {
  decode(value, path = '') {
    if (typeof value !== 'number' || !Number.isSafeInteger(value)) {
      throw new DecodingError(path, 'expected a safe integer');
    }
    return value;
  },
  encode: (value) => value,
};

export const decimal: Codec<Decimal> = {
  decode(value, path = '') {
    if (typeof value === 'number' && Number.isFinite(value)) return new Big(value);
    if (typeof value === 'string' && value.trim() !== '') {
      try {
        return new Big(value);
      } catch {
        // Falls through to the shared error below.
      }
    }
    throw new DecodingError(path, 'expected a decimal number');
  },
  encode: (value) => value.toNumber(),
};

export const timestamp: Codec<Date> = {
  decode(value, path = '') {
    const date = typeof value === 'string' ? dateFromTimestamp(value) : null;
    if (!date) throw new DecodingError(path, 'expected an ISO 8601 timestamp with a timezone');
    return date;
  },
  encode: timestampFromDate,
};

export const json: Codec<JSONValue> = {
  decode(value, path = '') {
    if (value === undefined) throw new DecodingError(path, 'expected a JSON value');
    return value as JSONValue;
  },
  encode: (value) => value,
};

export const jsonObject: Codec<{ [key: string]: JSONValue }> = {
  decode(value, path = '') {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      throw new DecodingError(path, 'expected a JSON object');
    }
    return value as { [key: string]: JSONValue };
  },
  encode: (value) => value,
};

export function enumOf<const Values extends readonly string[]>(values: Values): Codec<Values[number]> {
  return {
    decode(value, path = '') {
      if (typeof value !== 'string' || !values.includes(value)) {
        throw new DecodingError(path, `expected one of ${values.join(', ')}`);
      }
      return value;
    },
    encode: (value) => value,
  };
}

/** A missing or null column decodes to null; null is omitted when encoding. */
export function nullable<T>(codec: Codec<T>): Codec<T | null> {
  return {
    decode: (value, path) => (value === null || value === undefined ? null : codec.decode(value, path)),
    encode: (value) => (value === null ? undefined : codec.encode(value)),
  };
}

/** Like `nullable`, but null is written explicitly so an update can clear the column. */
export function nullableExplicit<T>(codec: Codec<T>): Codec<T | null> {
  return {
    decode: nullable(codec).decode,
    encode: (value) => (value === null ? null : codec.encode(value)),
  };
}

export function arrayOf<T>(codec: Codec<T>): Codec<T[]> {
  return {
    decode(value, path = '') {
      if (!Array.isArray(value)) throw new DecodingError(path, 'expected an array');
      return value.map((item, index) => codec.decode(item, `${path}[${index}]`));
    },
    encode: (value) => value.map((item) => codec.encode(item)),
  };
}

type Field<T> = readonly [wireKey: string, codec: Codec<T>];
type Shape = Record<string, Field<any>>;
type Decoded<S extends Shape> = { readonly [K in keyof S]: S[K] extends Field<infer T> ? T : never };

/** Maps camelCase model properties to their exact wire column names. */
export function struct<S extends Shape>(shape: S): Codec<Decoded<S>> {
  const fields = Object.entries(shape);
  return {
    decode(value, path = '') {
      if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        throw new DecodingError(path, 'expected an object');
      }
      const row = value as Record<string, unknown>;
      const model: Record<string, unknown> = {};
      for (const [property, [wireKey, codec]] of fields) {
        model[property] = codec.decode(row[wireKey], path ? `${path}.${wireKey}` : wireKey);
      }
      return model as Decoded<S>;
    },
    encode(model) {
      const row: Record<string, unknown> = {};
      for (const [property, [wireKey, codec]] of fields) {
        const encoded = codec.encode((model as Record<string, unknown>)[property]);
        if (encoded !== undefined) row[wireKey] = encoded;
      }
      return row;
    },
  };
}
