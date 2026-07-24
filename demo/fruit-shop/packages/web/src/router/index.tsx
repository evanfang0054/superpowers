import { createBrowserRouter, Navigate, useLocation } from 'react-router-dom';
import { lazy, Suspense } from 'react';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { useAuthStore } from '@/store/auth.store';
import { UserRole } from 'shared';

const Home = lazy(() => import('@/pages/Home'));
const ProductDetail = lazy(() => import('@/pages/ProductDetail'));
const Cart = lazy(() => import('@/pages/Cart'));
const Checkout = lazy(() => import('@/pages/Checkout'));
const OrderList = lazy(() => import('@/pages/OrderList'));
const OrderDetail = lazy(() => import('@/pages/OrderDetail'));
const Profile = lazy(() => import('@/pages/Profile'));
const Addresses = lazy(() => import('@/pages/Addresses'));
const Favorites = lazy(() => import('@/pages/Favorites'));
const Login = lazy(() => import('@/pages/Login'));
const Register = lazy(() => import('@/pages/Register'));
const AdminProducts = lazy(() => import('@/pages/AdminProducts'));
const AdminBanners = lazy(() => import('@/pages/AdminBanners'));
const AdminRefunds = lazy(() => import('@/pages/AdminRefunds'));
const AdminCoupons = lazy(() => import('@/pages/AdminCoupons'));
const AdminCategories = lazy(() => import('@/pages/AdminCategories'));
const MyCoupons = lazy(() => import('@/pages/MyCoupons'));

function SuspenseWrapper({ children }: { children: React.ReactNode }) {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-screen">
          <LoadingSpinner size="lg" />
        </div>
      }
    >
      {children}
    </Suspense>
  );
}

// 登录保护：未登录跳转到 /login，携带来源路径以便登录后回跳
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const token = useAuthStore((s) => s.token);
  const location = useLocation();
  if (!token) return <Navigate to="/login" replace state={{ from: location }} />;
  return <>{children}</>;
}

// 管理员保护：非管理员跳转到首页
function AdminRoute({ children }: { children: React.ReactNode }) {
  const token = useAuthStore((s) => s.token);
  const user = useAuthStore((s) => s.user);
  if (!token) return <Navigate to="/login" replace />;
  if (user?.role !== UserRole.ADMIN) return <Navigate to="/" replace />;
  return <>{children}</>;
}

export const router = createBrowserRouter([
  {
    path: '/',
    element: (
      <SuspenseWrapper>
        <Home />
      </SuspenseWrapper>
    ),
  },
  {
    path: '/product/:id',
    element: (
      <SuspenseWrapper>
        <ProductDetail />
      </SuspenseWrapper>
    ),
  },
  {
    path: '/cart',
    element: (
      <SuspenseWrapper>
        <ProtectedRoute>
          <Cart />
        </ProtectedRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/checkout',
    element: (
      <SuspenseWrapper>
        <ProtectedRoute>
          <Checkout />
        </ProtectedRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/orders',
    element: (
      <SuspenseWrapper>
        <ProtectedRoute>
          <OrderList />
        </ProtectedRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/order/:id',
    element: (
      <SuspenseWrapper>
        <ProtectedRoute>
          <OrderDetail />
        </ProtectedRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/profile',
    element: (
      <SuspenseWrapper>
        <ProtectedRoute>
          <Profile />
        </ProtectedRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/addresses',
    element: (
      <SuspenseWrapper>
        <ProtectedRoute>
          <Addresses />
        </ProtectedRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/favorites',
    element: (
      <SuspenseWrapper>
        <ProtectedRoute>
          <Favorites />
        </ProtectedRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/coupons/mine',
    element: (
      <SuspenseWrapper>
        <ProtectedRoute>
          <MyCoupons />
        </ProtectedRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/login',
    element: (
      <SuspenseWrapper>
        <Login />
      </SuspenseWrapper>
    ),
  },
  {
    path: '/register',
    element: (
      <SuspenseWrapper>
        <Register />
      </SuspenseWrapper>
    ),
  },
  {
    path: '/admin/products',
    element: (
      <SuspenseWrapper>
        <AdminRoute>
          <AdminProducts />
        </AdminRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/admin/banners',
    element: (
      <SuspenseWrapper>
        <AdminRoute>
          <AdminBanners />
        </AdminRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/admin/refunds',
    element: (
      <SuspenseWrapper>
        <AdminRoute>
          <AdminRefunds />
        </AdminRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/admin/coupons',
    element: (
      <SuspenseWrapper>
        <AdminRoute>
          <AdminCoupons />
        </AdminRoute>
      </SuspenseWrapper>
    ),
  },
  {
    path: '/admin/categories',
    element: (
      <SuspenseWrapper>
        <AdminRoute>
          <AdminCategories />
        </AdminRoute>
      </SuspenseWrapper>
    ),
  },
]);
