import React, { type ComponentType } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { pagesConfig } from './pages.config';
import { AuthProvider } from './lib/AuthContext';

type PageComponent = ComponentType<Record<string, unknown>>;

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
      staleTime: 1000 * 30,
    },
  },
});

const Pages: Record<string, PageComponent> =
  pagesConfig.Pages as Record<string, PageComponent>;
const Layout: ComponentType<{
  currentPageName?: string;
  children?: React.ReactNode;
}> = pagesConfig.Layout;
const mainKey: string = pagesConfig.mainPage ?? Object.keys(Pages)[0];

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route
              path="/"
              element={
                <Layout currentPageName={mainKey}>
                  {React.createElement(Pages[mainKey])}
                </Layout>
              }
            />
            {Object.entries(Pages).map(([key, Component]) => (
              <Route
                key={key}
                path={`/${key}`}
                element={
                  <Layout currentPageName={key}>
                    <Component />
                  </Layout>
                }
              />
            ))}
            {/* Fallback: unknown paths redirect to main page */}
            <Route path="*" element={<Navigate to={`/${mainKey}`} replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  );
}
