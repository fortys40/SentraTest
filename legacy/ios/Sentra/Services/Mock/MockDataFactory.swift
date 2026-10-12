import Foundation

struct MockDataset: Hashable, Sendable {
    let referenceDate: Date
    let group: Group
    let profiles: [Profile]
    let members: [GroupMember]
    let guests: [Guest]
    let upcomingMatch: Match
    let pastMatches: [Match]
    let responses: [RSVPWithWaitlistPosition]
    let participants: [MatchParticipant]
    let goals: [Goal]
    let payments: [Payment]
    let mvpResults: [MVPResult]
    let stats: [PlayerStats]
    let ratingHistory: [RatingHistoryEntry]
    let badgeDefinitions: [BadgeDefinition]
    let badges: [PlayerBadge]
    let cardExamples: [PlayerCardExample]

    var matches: [Match] { [upcomingMatch] + pastMatches.reversed() }
}

enum MockDataFactory {
    static let referenceDate = Date(timeIntervalSince1970: 1_791_374_400)

    static func make(referenceDate: Date = MockDataFactory.referenceDate) -> MockDataset {
        let createdAt = referenceDate.addingTimeInterval(-90 * 86_400)
        let positions: [FootballPosition] = [
            .goalkeeper, .defender, .midfielder, .midfielder, .forward, .goalkeeper,
            .defender, .midfielder, .forward, .forward, .defender, .any
        ]
        let profiles = positions.enumerated().map { index, position in
            Profile(
                id: identifier(0x20, index + 1),
                displayName: greek(String(format: "mock.player.%02d", index + 1)),
                position: position, avatarURL: nil, onboardingCompleted: true,
                createdAt: createdAt, updatedAt: createdAt
            )
        }
        let format = MatchFormat.fiveASide
        let group = Group(
            id: identifier(0x30, 1), name: greek("mock.group"), ownerID: profiles[0].id,
            defaultFormat: format.code, createdAt: createdAt, updatedAt: createdAt
        )
        let members = profiles.enumerated().map { index, profile in
            GroupMember(
                id: identifier(0x31, index + 1), groupID: group.id, userID: profile.id,
                role: index == 0 ? .owner : (index == 1 ? .admin : .member),
                joinedAt: createdAt, leftAt: nil
            )
        }
        let guest = Guest(
            id: identifier(0x50, 1), groupID: group.id, name: greek("mock.guest"),
            invitedBy: profiles[2].id, claimedByUserID: nil, claimedAt: nil,
            createdAt: createdAt, updatedAt: createdAt
        )
        let kickoff = referenceDate.addingTimeInterval(6 * 86_400 + 6 * 3_600)
        let upcoming = match(
            index: 7, group: group, startsAt: kickoff, createdAt: createdAt, finished: false
        )
        let responses = profiles.enumerated().map { index, profile in
            let status: RSVPStatus = index < 9 ? .yes : (index == 9 ? .maybe : (index == 10 ? .no : .waitlist))
            let changedAt = referenceDate.addingTimeInterval(Double(index * 60 - 3_600))
            return RSVPWithWaitlistPosition(
                response: RSVP(
                    id: identifier(0x60, index + 1), matchID: upcoming.id, groupID: group.id,
                    userID: profile.id, guestID: nil, status: status,
                    waitlistedAt: status == .waitlist ? changedAt : nil,
                    waitlistOrder: status == .waitlist ? 42 : nil,
                    createdAt: changedAt, updatedAt: changedAt
                ),
                positionInWaitlist: status == .waitlist ? 1 : nil
            )
        } + [RSVPWithWaitlistPosition(
            response: RSVP(
                id: identifier(0x60, 13), matchID: upcoming.id, groupID: group.id,
                userID: nil, guestID: guest.id, status: .yes,
                waitlistedAt: nil, waitlistOrder: nil,
                createdAt: referenceDate.addingTimeInterval(-7_200), updatedAt: referenceDate
            ),
            positionInWaitlist: nil
        )]
        let pastMatches = (0..<6).map { index in
            match(
                index: index + 1, group: group,
                startsAt: kickoff.addingTimeInterval(-Double(6 - index) * 7 * 86_400),
                createdAt: createdAt, finished: true
            )
        }
        let participants = pastMatches.enumerated().flatMap { matchIndex, match in
            profiles.enumerated().filter { playerIndex, _ in
                playerIndex != matchIndex * 2 && playerIndex != matchIndex * 2 + 1
            }.enumerated().map { rosterIndex, entry in
                MatchParticipant(
                    id: identifier(0x70, matchIndex * 100 + rosterIndex + 1),
                    matchID: match.id, groupID: group.id, userID: entry.element.id, guestID: nil,
                    team: rosterIndex < format.playersPerTeam ? .a : .b,
                    chargedToUserID: entry.element.id,
                    createdAt: match.finishedAt ?? match.startsAt
                )
            }
        }
        let goals = pastMatches.enumerated().flatMap { matchIndex, match -> [Goal] in
            guard match.goalsRecorded else { return [] }
            let roster = participants.filter { $0.matchID == match.id }
            return [0, format.playersPerTeam].map { rosterIndex in
                Goal(
                    id: identifier(0x80, matchIndex * 100 + rosterIndex + 1),
                    matchID: match.id, scorerParticipantID: roster[rosterIndex].id,
                    team: rosterIndex == 0 ? .a : .b, minute: rosterIndex == 0 ? 12 : 35,
                    createdAt: match.finishedAt ?? match.startsAt
                )
            }
        }
        let payments = pastMatches.filter(\.costSplitEnabled).flatMap { match in
            participants.filter { $0.matchID == match.id }.enumerated().map { index, participant in
                Payment(
                    id: identifier(0x90, index + 1), matchID: match.id, groupID: group.id,
                    debtorUserID: participant.chargedToUserID, amount: match.shareAmount ?? .zero,
                    includesGuestIDs: [], paid: index < 2,
                    paidAt: index < 2 ? match.finishedAt : nil, updatedBy: group.ownerID,
                    createdAt: match.finishedAt ?? match.startsAt,
                    updatedAt: match.finishedAt ?? match.startsAt
                )
            }
        }
        let mvpResults = pastMatches.enumerated().compactMap { index, match -> MVPResult? in
            let winnerID = index == 0 ? profiles[2].id : profiles[0].id
            guard let candidate = participants.first(where: { $0.matchID == match.id && $0.userID == winnerID }) else {
                return nil
            }
            return MVPResult(
                id: identifier(0xa0, index + 1), matchID: match.id, participantID: candidate.id,
                votes: format.capacity - 1, createdAt: match.mvpClosedAt ?? match.startsAt
            )
        }
        let stats = profiles.flatMap { profile -> [PlayerStats] in
            let played = participants.filter { $0.userID == profile.id }
            let playedIDs = Set(played.map(\.id))
            let playedMatchIDs = Set(played.map(\.matchID))
            let wins = played.filter { participant in
                let winner = pastMatches.first(where: { $0.id == participant.matchID })?.winner
                return (winner == .a && participant.team == .a) || (winner == .b && participant.team == .b)
            }.count
            let losses = played.filter { participant in
                let winner = pastMatches.first(where: { $0.id == participant.matchID })?.winner
                return (winner == .a && participant.team == .b) || (winner == .b && participant.team == .a)
            }.count
            let draws = pastMatches.filter { playedMatchIDs.contains($0.id) && $0.winner == .draw }.count
            let decided = wins + losses + draws
            let winPercentage = decided == 0 ? nil : Decimal(wins * 100) / Decimal(decided)
            let scopes: [UUID?] = [group.id, nil]
            return scopes.map { scope in
                PlayerStats(
                    userID: profile.id, groupID: scope, appearances: Int64(played.count),
                    wins: Int64(wins), losses: Int64(losses), draws: Int64(draws),
                    goals: Int64(goals.filter { playedIDs.contains($0.scorerParticipantID) }.count),
                    mvpCount: Int64(mvpResults.filter { playedIDs.contains($0.participantID) }.count),
                    winPercentage: winPercentage,
                    currentStreak: Int64(pastMatches.reversed().prefix { playedMatchIDs.contains($0.id) }.count)
                )
            }
        }
        let definitions = badgeDefinitions(createdAt: createdAt)
        let badges: [PlayerBadge] = [group.id, nil].enumerated().map { index, scope in
            PlayerBadge(
                id: identifier(0xc0, index + 1), userID: profiles[0].id, groupID: scope,
                badgeCode: "mvp_5", ruleSnapshot: .object(definitions[2].ruleParams),
                awardedAt: pastMatches[5].mvpClosedAt ?? referenceDate
            )
        }
        let profileIndices = [2, 4, 6, 0]
        let overalls = [63, 71, 82, 90]
        let titles: [PreviewPlayerTitle] = [.everPresent, .scorer, .wall, .mvpMachine]
        let cards = profileIndices.enumerated().compactMap { index, profileIndex -> PlayerCardExample? in
            let profile = profiles[profileIndex]
            guard let statistics = stats.first(where: { $0.userID == profile.id && $0.groupID == group.id }) else {
                return nil
            }
            let tier = CardTier(overall: overalls[index])
            return PlayerCardExample(
                profile: profile, groupName: group.name, stats: statistics, overall: overalls[index],
                title: titles[index], design: CardDesign(id: "preview.\(tier.rawValue)", tier: tier),
                badges: profile.id == group.ownerID ? [definitions[2]] : []
            )
        }
        let ratingHistory = cards.enumerated().flatMap { cardIndex, card in
            let playedMatchIDs = Set(participants.filter { $0.userID == card.profile.id }.map(\.matchID))
            let playedMatches = pastMatches.filter { playedMatchIDs.contains($0.id) }
            return playedMatches.enumerated().map { index, match in
                RatingHistoryEntry(
                    id: identifier(0xd0, cardIndex * 100 + index + 1), userID: card.profile.id,
                    groupID: group.id, matchID: match.id,
                    overall: card.overall - (playedMatches.count - index - 1) * 2,
                    recordedAt: match.finishedAt ?? match.startsAt
                )
            }
        }
        return MockDataset(
            referenceDate: referenceDate, group: group, profiles: profiles, members: members,
            guests: [guest], upcomingMatch: upcoming, pastMatches: pastMatches, responses: responses,
            participants: participants, goals: goals, payments: payments, mvpResults: mvpResults,
            stats: stats, ratingHistory: ratingHistory, badgeDefinitions: definitions,
            badges: badges, cardExamples: cards
        )
    }

    static func identifier(_ namespace: UInt8, _ index: Int) -> UUID {
        let value = UInt32(index)
        return UUID(uuid: (
            namespace, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            UInt8((value >> 24) & 255), UInt8((value >> 16) & 255),
            UInt8((value >> 8) & 255), UInt8(value & 255)
        ))
    }

    private static func greek(_ key: String) -> String {
        String(localized: String.LocalizationValue(stringLiteral: key), locale: Locale(identifier: "el"))
    }

    private static func match(index: Int, group: Group, startsAt: Date, createdAt: Date, finished: Bool) -> Match {
        let format = MatchFormat.fiveASide
        let winner: MatchWinner? = !finished || index == 1 ? nil : (index == 2 ? .b : (index == 4 ? .draw : .a))
        let hasScore = finished && index >= 3
        let hasSplit = finished && index == 6
        let completedAt = finished ? startsAt.addingTimeInterval(90 * 60) : nil
        return Match(
            id: identifier(0x40, index), groupID: group.id, seriesID: nil, occurrenceDate: nil,
            format: format.code, playersPerTeam: format.playersPerTeam, capacity: format.capacity,
            venue: greek("mock.venue"), startsAt: startsAt,
            rsvpLockAt: startsAt.addingTimeInterval(-2 * 3_600), expectedCost: Decimal(60),
            status: finished ? .finished : .scheduled, winner: winner,
            scoreA: hasScore ? (winner == .draw ? 2 : 3) : nil, scoreB: hasScore ? 2 : nil,
            goalsRecorded: hasScore, finishedAt: completedAt,
            mvpVotingClosesAt: completedAt?.addingTimeInterval(24 * 3_600),
            mvpClosedAt: completedAt?.addingTimeInterval(3_600), costSplitEnabled: hasSplit,
            totalCost: hasSplit ? Decimal(60) : nil, paidBy: hasSplit ? group.ownerID : nil,
            shareAmount: hasSplit ? Decimal(60) / Decimal(format.capacity) : nil,
            roundingRemainder: hasSplit ? .zero : nil,
            createdAt: createdAt, updatedAt: completedAt ?? createdAt
        )
    }

    private static func badgeDefinitions(createdAt: Date) -> [BadgeDefinition] {
        let codes = ["attendance_streak", "ghost", "mvp_5"]
        let parameters: [[String: JSONValue]] = [
            ["metric": .string("current_streak"), "threshold": .number(10), "scopes": .array([.string("group")])],
            ["metric": .string("late_cancellations"), "threshold": .number(3), "lookback_matches": .number(10),
             "late_hours": .number(24), "scopes": .array([.string("group")])],
            ["metric": .string("mvp_count"), "threshold": .number(5), "scopes": .array([.string("group"), .string("overall")])]
        ]
        return codes.enumerated().map { index, code in
            BadgeDefinition(
                id: identifier(0xb0, index + 1), code: code, nameEL: greek("mock.badge.\(code).name"),
                emoji: greek("mock.badge.\(code).emoji"), descriptionEL: greek("mock.badge.\(code).description"),
                ruleParams: parameters[index], active: true, createdAt: createdAt, updatedAt: createdAt
            )
        }
    }
}