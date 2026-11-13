export interface PortalTask {
  id: string;
  title: string;
  description?: string | null;
  status?: string | null;
  deadline?: string | null;
  resource_url?: string | null;
  archived?: boolean;
  points?: number;
  completed_at?: string | null;
}
export interface PortalProfile {
  score?: number;
  member: {
    bio?: string | null;
    id: string; name: string; email: string; phone?: string | null;
    avatar?: string | null; company?: string | null; job_title?: string | null; comm_title?: string | null;
  };
  tasks: PortalTask[];
  org_department_members?: { id: string; department?: { id: string; name: string } }[];
}
