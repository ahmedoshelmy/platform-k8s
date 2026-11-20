{{- define "listmate.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Selector labels for one tier; call with (dict "ctx" $ "component" "api"). */}}
{{- define "listmate.selectorLabels" -}}
app.kubernetes.io/name: {{ .ctx.Chart.Name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "listmate.labels" -}}
{{ include "listmate.selectorLabels" . }}
app.kubernetes.io/part-of: {{ .ctx.Release.Name }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .ctx.Chart.Name .ctx.Chart.Version }}
{{- end -}}

{{- define "listmate.secretName" -}}
{{- default (printf "%s-db" .Release.Name) .Values.secrets.existingSecret -}}
{{- end -}}

{{- define "listmate.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ include "listmate.fullname" . }}{{- else -}}default{{- end -}}
{{- end -}}

{{- define "listmate.dbHost" -}}
{{- default (printf "%s-postgres" .Release.Name) .Values.database.host -}}
{{- end -}}

{{/* More than one API pod needs the backplane, or SignalR clients on one pod miss updates written through another. */}}
{{- define "listmate.validate" -}}
{{- $scaled := or .Values.api.autoscaling.enabled (gt (int .Values.api.replicaCount) 1) -}}
{{- if and $scaled (not .Values.redisBackplane.enabled) -}}
{{- fail "listmate: api.replicaCount > 1 or api.autoscaling.enabled needs redisBackplane.enabled=true (SignalR backplane + shared key ring)" -}}
{{- end -}}
{{- end -}}

{{- define "listmate.podSecurityContext" -}}
runAsNonRoot: true
seccompProfile: { type: RuntimeDefault }
{{- end -}}

{{- define "listmate.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities: { drop: [ALL] }
{{- end -}}
