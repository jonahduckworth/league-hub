import '../models/league.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import '../models/document.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';

final mockLeagues = [
  League(id: 'l1', orgId: 'demo-org-1', name: 'Premier League', abbreviation: 'PL', createdAt: DateTime.now()),
  League(id: 'l2', orgId: 'demo-org-1', name: 'Division I', abbreviation: 'D1', createdAt: DateTime.now()),
  League(id: 'l3', orgId: 'demo-org-1', name: 'Youth League', abbreviation: 'YL', createdAt: DateTime.now()),
];

final mockChatRooms = [
  ChatRoom(id: 'cr1', orgId: 'demo-org-1', name: 'PL - General', type: ChatRoomType.league, leagueId: 'l1', participants: [], createdAt: DateTime.now(), isArchived: false, lastMessage: 'Game schedule updated for next week', lastMessageAt: DateTime.now().subtract(const Duration(minutes: 15))),
  ChatRoom(id: 'cr2', orgId: 'demo-org-1', name: 'D1 - Coaches', type: ChatRoomType.league, leagueId: 'l2', participants: [], createdAt: DateTime.now(), isArchived: false, lastMessage: 'Please confirm your roster submission', lastMessageAt: DateTime.now().subtract(const Duration(hours: 2))),
  ChatRoom(id: 'cr3', orgId: 'demo-org-1', name: 'Spring Tournament 2025', type: ChatRoomType.event, participants: [], createdAt: DateTime.now(), isArchived: false, lastMessage: 'Registration closes Friday!', lastMessageAt: DateTime.now().subtract(const Duration(hours: 5))),
  ChatRoom(id: 'cr4', orgId: 'demo-org-1', name: 'Sarah Johnson', type: ChatRoomType.direct, participants: ['u1', 'u2'], createdAt: DateTime.now(), isArchived: false, lastMessage: 'Thanks for the update', lastMessageAt: DateTime.now().subtract(const Duration(days: 1))),
];

final mockMessages = [
  Message(id: 'm1', chatRoomId: 'cr1', senderId: 'other1', senderName: 'Sarah Johnson', text: 'Hey team! Just a reminder that practice is at 6pm tonight at Field 3.', createdAt: DateTime.now().subtract(const Duration(hours: 2)), readBy: ['currentUser']),
  Message(id: 'm2', chatRoomId: 'cr1', senderId: 'other2', senderName: 'Mike Chen', text: 'Thanks for the reminder! Will the equipment be set up beforehand?', createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)), readBy: ['currentUser']),
  Message(id: 'm3', chatRoomId: 'cr1', senderId: 'currentUser', senderName: 'You', text: 'Yes, I\'ll be there early to set everything up. See you all at 6!', createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)), readBy: ['other1', 'other2']),
  Message(id: 'm4', chatRoomId: 'cr1', senderId: 'other1', senderName: 'Sarah Johnson', text: 'Check out this highlight reel from last week\'s game!', mediaUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', createdAt: DateTime.now().subtract(const Duration(minutes: 45)), readBy: ['currentUser']),
  Message(id: 'm5', chatRoomId: 'cr1', senderId: 'currentUser', senderName: 'You', text: 'Great game everyone! Looking forward to the next one.', createdAt: DateTime.now().subtract(const Duration(minutes: 10)), readBy: ['other1']),
];

final mockDocuments = [
  Document(id: 'd1', orgId: 'demo-org-1', leagueId: 'l1', name: 'PL Season Roster 2025.pdf', fileUrl: '', fileType: 'pdf', fileSize: 245760, category: 'Rosters', uploadedBy: 'u1', uploadedByName: 'Admin', versions: [], createdAt: DateTime.now().subtract(const Duration(days: 2)), updatedAt: DateTime.now().subtract(const Duration(days: 2))),
  Document(id: 'd2', orgId: 'demo-org-1', leagueId: 'l2', name: 'Player Waiver Form 2025.docx', fileUrl: '', fileType: 'docx', fileSize: 102400, category: 'Waivers', uploadedBy: 'u1', uploadedByName: 'Admin', versions: [], createdAt: DateTime.now().subtract(const Duration(days: 5)), updatedAt: DateTime.now().subtract(const Duration(days: 3))),
  Document(id: 'd3', orgId: 'demo-org-1', leagueId: 'l1', name: 'Spring Schedule 2025.xlsx', fileUrl: '', fileType: 'xlsx', fileSize: 51200, category: 'Schedules', uploadedBy: 'u1', uploadedByName: 'Admin', versions: [], createdAt: DateTime.now().subtract(const Duration(days: 1)), updatedAt: DateTime.now().subtract(const Duration(hours: 6))),
  Document(id: 'd4', orgId: 'demo-org-1', name: 'League Code of Conduct.pdf', fileUrl: '', fileType: 'pdf', fileSize: 307200, category: 'Policies', uploadedBy: 'u1', uploadedByName: 'Admin', versions: [], createdAt: DateTime.now().subtract(const Duration(days: 30)), updatedAt: DateTime.now().subtract(const Duration(days: 30))),
  Document(id: 'd5', orgId: 'demo-org-1', leagueId: 'l3', name: 'Youth League Roster U12.pdf', fileUrl: '', fileType: 'pdf', fileSize: 184320, category: 'Rosters', uploadedBy: 'u1', uploadedByName: 'Admin', versions: [], createdAt: DateTime.now().subtract(const Duration(days: 4)), updatedAt: DateTime.now().subtract(const Duration(days: 4))),
];

final mockAnnouncements = [
  Announcement(id: 'a1', orgId: 'demo-org-1', scope: AnnouncementScope.orgWide, title: 'Welcome to League Hub!', body: 'We are excited to launch League Hub for all our leagues and teams. This platform will be your central hub for communication, documents, and league management.', authorId: 'u1', authorName: 'Commissioner Davis', authorRole: 'Platform Owner', attachments: [], isPinned: true, createdAt: DateTime.now().subtract(const Duration(days: 1))),
  Announcement(id: 'a2', orgId: 'demo-org-1', scope: AnnouncementScope.league, leagueId: 'l1', title: 'PL Roster Submission Deadline', body: 'All Premier League teams must submit their final rosters by this Friday, March 21st. Late submissions will not be accepted. Please upload your roster documents to the Documents section.', authorId: 'u2', authorName: 'Sarah Johnson', authorRole: 'Super Admin', attachments: [], isPinned: false, createdAt: DateTime.now().subtract(const Duration(hours: 6))),
  Announcement(id: 'a3', orgId: 'demo-org-1', scope: AnnouncementScope.hub, hubId: 'h1', title: 'Field Maintenance - Field 3 Closed', body: 'Field 3 at the North Hub will be closed for maintenance from March 19-21. All practices and games scheduled at Field 3 will need to be relocated. Please contact your hub manager for alternative field assignments.', authorId: 'u3', authorName: 'Mike Chen', authorRole: 'Manager Admin', attachments: [], isPinned: false, createdAt: DateTime.now().subtract(const Duration(days: 2))),
];

final mockCurrentUser = AppUser(
  id: 'currentUser',
  email: 'admin@leaguehub.com',
  displayName: 'Alex Commissioner',
  role: UserRole.platformOwner,
  orgId: 'demo-org-1',
  hubIds: [],
  teamIds: [],
  createdAt: DateTime.now().subtract(const Duration(days: 90)),
  isActive: true,
);
