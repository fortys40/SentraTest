import {
  arrayOf,
  boolean,
  decimal,
  nullable,
  string,
  struct,
  timestamp,
  uuid,
  type CodecType,
} from '@/core/utilities/SentraJSON';

export const PaymentCodec = struct({
  id: ['id', uuid],
  matchID: ['match_id', uuid],
  groupID: ['group_id', uuid],
  debtorUserID: ['debtor_user_id', uuid],
  amount: ['amount', decimal],
  includesGuestIDs: ['includes_guest_ids', arrayOf(uuid)],
  paid: ['paid', boolean],
  paidAt: ['paid_at', nullable(timestamp)],
  updatedBy: ['updated_by', nullable(uuid)],
  createdAt: ['created_at', timestamp],
  updatedAt: ['updated_at', timestamp],
});
export type Payment = CodecType<typeof PaymentCodec>;

export const OutstandingPaymentCodec = struct({
  id: ['id', uuid],
  matchID: ['match_id', uuid],
  groupID: ['group_id', uuid],
  debtorUserID: ['debtor_user_id', uuid],
  amount: ['amount', decimal],
  includesGuestIDs: ['includes_guest_ids', arrayOf(uuid)],
  creditorUserID: ['creditor_user_id', uuid],
  creditorName: ['creditor_name', string],
});
export type OutstandingPayment = CodecType<typeof OutstandingPaymentCodec>;
