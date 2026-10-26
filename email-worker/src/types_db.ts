// Minimal types for query results used by the worker.
// (We avoid generating full Supabase Database types for this task.)

export interface Database {
  public: {
    Tables: {
      email_queue: {
        Row: {
          id: number;
          recipient_email: string;
          recipient_name: string | null;
          template_code: string;
          template_params: Record<string, unknown>;
          priority: 'low' | 'medium' | 'high';
          status: 'pending' | 'sent' | 'failed';
          attempt_count: number;
          last_attempt_at: string | null;
          next_attempt_at: string;
          sent_at: string | null;
          error_message: string | null;
          brevo_message_id: string | null;
          created_at: string;
          updated_at: string;
        };
      };
      speaker_email_queue: {
        Row: {
          id: string;
          speaker_id: string;
          email_type: string;
          status: 'pending' | 'sent' | 'failed';
          error_message: string | null;
          retry_count: number;
          scheduled_at: string;
          sent_at: string | null;
          created_at: string;
        };
      };
      speakers: {
        Row: {
          id: string;
          email: string | null;
          full_name: string | null;
          title: string | null;
          company: string | null;
          status: string;
        };
      };
      email_templates: {
        Row: {
          id: number;
          template_code: string;
          brevo_template_id: number | null;
          subject: string;
          html_content: string;
          is_active: boolean;
          created_at: string;
        };
      };
      email_settings: {
        Row: {
          id: number;
          setting_key: string;
          setting_value: string | null;
          updated_at: string;
        };
      };
      email_send_logs: {
        Row: {
          id: number;
          queue_id: number | null;
          speaker_queue_id: string | null;
          recipient_email: string;
          template_code: string;
          event_type: string;
          event_data: Record<string, unknown>;
          created_at: string;
        };
      };


    };
    Functions: {
      enqueue_birthday_emails: {
        Args: { p_personal_only?: boolean };
        Returns: undefined;
      };
      record_birthday_email_delivery: {
        Args: {
          p_queue_id: number;
          p_birthday_person_id: string;
          p_notification_year: number;
          p_channel: 'personal' | 'team';
        };
        Returns: undefined;
      };

    };
  };
}
