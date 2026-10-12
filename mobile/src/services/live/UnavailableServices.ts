import { AppError } from '@/core/utilities/AppError';

import type {
  BadgeService,
  CalendarService,
  CostSplitService,
  GuestService,
  NotificationService,
  RatingService,
  ResultService,
  StatsService,
  VotingService,
} from '../protocols/ServiceProtocols';

const unavailable = async (): Promise<never> => {
  throw new AppError('unavailable');
};

/** Services without a reviewed live contract fail explicitly; they never substitute mock data. */
export class UnavailableServices
  implements
    GuestService,
    ResultService,
    CostSplitService,
    VotingService,
    StatsService,
    RatingService,
    BadgeService,
    CalendarService,
    NotificationService
{
  fetchGuests = unavailable;
  fetchParticipants = unavailable;
  fetchGoals = unavailable;
  fetchPayments = unavailable;
  fetchVotingState = unavailable;
  fetchMVPResults = unavailable;
  fetchStats = unavailable;
  fetchRatingHistory = unavailable;
  fetchBadgeDefinitions = unavailable;
  fetchBadges = unavailable;
  calendarPermission = unavailable;
  addMatchToCalendar = unavailable;
  notificationPermission = unavailable;
  requestNotificationPermission = unavailable;
}
