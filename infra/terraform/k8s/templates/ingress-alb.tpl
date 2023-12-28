---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/certificate-arn: "${acm_certificate}"
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-Ext-2018-06
    alb.ingress.kubernetes.io/healthcheck-path: /healthz
    alb.ingress.kubernetes.io/scheme: "${alb_schema}"
    alb.ingress.kubernetes.io/subnets: "${subnet_lists}"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
  %{ if can(alb_security_groups) }
    alb.ingress.kubernetes.io/security-groups: "${alb_security_groups}"
    alb.ingress.kubernetes.io/manage-backend-security-group-rules: "true"
  %{ endif }
  %{ if can(waf_arn) }
    alb.ingress.kubernetes.io/wafv2-acl-arn: ${waf_arn}
  %{ endif }
  name: "${ingress_name}"
  namespace: "${namespace}"
spec:
  defaultBackend:
    service:
      name: "${backend_service}"
      port:
        name: http
