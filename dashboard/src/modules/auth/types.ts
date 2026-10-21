export interface AdminMe {
  id: number;
  name: string;
  phone_masked: string;
  roles: string[];
  permissions: string[];
}

export interface AccessResponse {
  access: string;
}
