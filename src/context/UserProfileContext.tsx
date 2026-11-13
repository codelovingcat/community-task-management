// ============================================================
// User Profile Context - Zincir Atarlı Task Management
// ============================================================

import React, { createContext, useContext, useEffect, useRef, useState, ReactNode } from 'react';
import { supabase } from '../lib/supabase';
import { getCurrentMember } from '../lib/supabaseMembers';
import { FullMember } from '../types/member';
import { User, Session } from '@supabase/supabase-js';

// Context type
interface UserProfileContextType {
  user: User | null;
  profile: FullMember | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

// Default values
const defaultContext: UserProfileContextType = {
  user: null,
  profile: null,
  isLoading: true,
  isAuthenticated: false,
  signOut: async () => {},
  refreshProfile: async () => {},
};

// Create context
const UserProfileContext = createContext<UserProfileContextType>(defaultContext);

// Provider props
interface UserProfileProviderProps {
  children: ReactNode;
}

// Provider component
export const UserProfileProvider: React.FC<UserProfileProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<FullMember | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Every auth change invalidates in-flight profile requests. A slow response
  // for the previous account must never become the current account's profile.
  const generation = useRef(0);
  const currentUser = useRef<User | null>(null);
  const mounted = useRef(false);

  const loadProfile = async (request: number) => {
    try {
      const result = await getCurrentMember();
      if (mounted.current && generation.current === request) setProfile(result);
    } catch {
      if (mounted.current && generation.current === request) setProfile(null);
    } finally {
      if (mounted.current && generation.current === request) setIsLoading(false);
    }
  };

  const applySession = (session: Session | null, deferLookup: boolean) => {
    const request = ++generation.current;
    const nextUser = session?.user ?? null;
    currentUser.current = nextUser;
    setProfile(null);
    setUser(nextUser);
    if (!nextUser) {
      setIsLoading(false);
      return;
    }
    setIsLoading(true);
    if (deferLookup) {
      // Avoid calling Supabase from inside onAuthStateChange's callback.
      setTimeout(() => {
        if (mounted.current && generation.current === request) void loadProfile(request);
      }, 0);
    } else {
      void loadProfile(request);
    }
  };

  useEffect(() => {
    mounted.current = true;
    const initialGeneration = generation.current;
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (!mounted.current) return;
      // Refreshing a token for the same account must not invalidate a profile
      // lookup already in flight.
      if (event === 'TOKEN_REFRESHED' && session && session.user.id === currentUser.current?.id) {
        currentUser.current = session.user;
        setUser(session.user);
        return;
      }
      applySession(session, true);
    });

    void supabase.auth.getSession().then(({ data: { session } }) => {
      if (mounted.current && generation.current === initialGeneration) applySession(session, false);
    }).catch(() => {
      if (mounted.current && generation.current === initialGeneration) applySession(null, false);
    });

    return () => {
      mounted.current = false;
      ++generation.current;
      subscription.unsubscribe();
    };
  }, []);

  const signOut = async () => {
    const request = generation.current;
    try {
      const { error } = await supabase.auth.signOut();
      if (error) return;
      if (mounted.current && generation.current === request) applySession(null, false);
    } catch {
      // Keep the active session visible if signing out failed.
    }
  };

  const refreshProfile = async () => {
    const target = currentUser.current;
    if (!target) return;
    const request = ++generation.current;
    setIsLoading(true);
    await loadProfile(request);
  };

  const value: UserProfileContextType = {
    user,
    profile,
    isLoading,
    isAuthenticated: !!user && !!profile,
    signOut,
    refreshProfile,
  };

  return (
    <UserProfileContext.Provider value={value}>
      {children}
    </UserProfileContext.Provider>
  );
};

// Custom hook to use the context
export const useUserProfile = () => {
  const context = useContext(UserProfileContext);
  
  if (!context) {
    throw new Error('useUserProfile must be used within a UserProfileProvider');
  }
  
  return context;
};

// Export the context itself for testing
export { UserProfileContext };

// ============================================================
// END OF USER PROFILE CONTEXT
// ============================================================
